class Risk < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :project
  belongs_to :author, :class_name => 'User'
  belongs_to :assigned_to, :class_name => 'Principal'
  belongs_to :category, :class_name => 'RiskCategory'

  has_many :journals, :as => :journalized, :dependent => :destroy, :inverse_of => :journalized

  has_and_belongs_to_many :issues, :join_table => 'risk_issues', :after_add => :relation_added, :after_remove => :relation_removed

  acts_as_customizable
  acts_as_searchable :columns => ['subject', "#{table_name}.description"],
                     :preload => [:project],
                     :scope => lambda {|options| options[:open_risks] ? self.open : self.all}

  acts_as_event :title => Proc.new {|o| l(:label_risk) + " ##{o.id}: #{o.subject}"},
                :url => Proc.new {|o| {:controller => 'risks', :action => 'show', :id => o.id}},
                :type => Proc.new {|o| 'risk' + (o.closed? ? '-closed' : '') }

  acts_as_activity_provider :scope => joins(:project).preload(:project, :author),
                            :author_key => :author_id

  attr_reader :current_journal
  delegate :notes, :notes=, :private_notes, :private_notes=, :to => :current_journal, :allow_nil => true

  RISK_PROBABILITY = %w(unlikely low medium high expected)
  RISK_IMPACT = %w(negligible minor moderate significant severe)
  RISK_MAGNITUDE = %w(low medium high extreme)
  RISK_STRATEGY = %w(accept mitigate transfer eliminate)

  validates_presence_of :subject, :project
  validates_presence_of :author, :if => Proc.new {|issue| issue.new_record? || issue.author_id_changed?}
  validates_length_of :subject, :maximum => 255
  validates_inclusion_of :probability, :in => 0..100, :allow_nil => true
  validates_inclusion_of :impact, :in => 0..100, :allow_nil => true
  validates_inclusion_of :strategy, :in => RISK_STRATEGY, :allow_blank => true

  attr_protected :id

  scope :open, lambda {|*args|
    is_closed = args.size > 0 ? !args.first : false

    if is_closed
      where.not(:closed_on => nil)
    else
      where(:closed_on => nil)
    end
  }

  scope :recently_updated, lambda { order(:updated_on => :desc) }

  scope :on_active_project, lambda {
    joins(:project).
      where(:projects => {:status => Project::STATUS_ACTIVE})
  }

  scope :assigned_to, lambda {|arg|
    arg = Array(arg).uniq
    ids = arg.map {|p| p.is_a?(Principal) ? p.id : p}
    ids += arg.select {|p| p.is_a?(User)}.map(&:group_ids).flatten.uniq
    ids.compact!
    ids.any? ? where(:assigned_to_id => ids) : none
  }

  scope :like, lambda {|q|
    q = q.to_s
    if q.present?
      where("LOWER(#{table_name}.subject) LIKE LOWER(?)", "%#{q}%")
    end
  }

  before_save :force_updated_on_change, :update_closed_on, :set_assigned_to_was
  after_save :create_journal

  state_machine :status, initial: :opened do
    event :close do
      transition [:opened] => :closed
    end

    event :reopen do
      transition [:closed] => :opened
    end

    before_transition from: [:closed, :merged] do |risk, transition|
      risk.closed_on  = nil
    end

    before_transition any => :closed do |risk, transition|
      risk.closed_on  = Time.now
    end

    state :opened
    state :closed
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(user=User.current)
    user.allowed_to?(:view_risks, self.project)
  end

  # Returns true if user or current user is allowed to edit or add notes to the issue
  def editable?(user=User.current)
    attributes_editable?(user)
  end

  def closable?(user=User.current)
    editable?(user) && ! closed?
  end

  # Returns true if user or current user is allowed to edit the issue
  def attributes_editable?(user=User.current)
    user_permission?(user, :edit_risks)
  end

  # Returns true if user or current user is allowed to add notes to the issue
  def notes_addable?(user=User.current)
    user_permission?(user, :add_issue_notes)
  end

  # Returns true if user or current user is allowed to delete the issue
  def deletable?(user=User.current)
    user_permission?(user, :delete_risks)
  end

  alias :base_reload :reload
  def reload(*args)
    @last_updated_by = nil
    @last_notes = nil
    base_reload(*args)
  end

  def category_id=(cid)
    self.category = nil
    write_attribute(:category_id, cid)
  end

  def project_id=(project_id)
    if project_id.to_s != self.project_id.to_s
      self.project = (project_id.present? ? Project.find_by_id(project_id) : nil)
    end
    self.project_id
  end

  def description=(arg)
    if arg.is_a?(String)
      arg = arg.gsub(/(\r\n|\n|\r)/, "\r\n")
    end
    write_attribute(:description, arg)
  end

  # Overrides assign_attributes so that project get assigned first
  def assign_attributes(new_attributes, *args)
    return if new_attributes.nil?
    attrs = new_attributes.dup
    attrs.stringify_keys!

    %w(project project_id).each do |attr|
      if attrs.has_key?(attr)
        send "#{attr}=", attrs.delete(attr)
      end
    end
    super attrs, *args
  end

  def attributes=(new_attributes)
    assign_attributes new_attributes
  end

  safe_attributes 'category_id',
                  'assigned_to_id',
                  'subject',
                  'description',
                  'probability',
                  'impact',
                  'strategy',
                  'treatments',
                  'lessons',
                  'custom_field_values',
                  'notes',
                  :if => lambda {|risk, user| risk.new_record? || risk.attributes_editable?(user) }

  safe_attributes 'project_id',
                  :if => lambda {|risk, user| risk.new_record? }

  safe_attributes 'status',
                  :if => lambda {|risk, user| !risk.new_record? && risk.attributes_editable?(user) }

  safe_attributes 'notes',
                  :if => lambda {|risk, user| risk.notes_addable?(user)}

  safe_attributes 'private_notes',
                  :if => lambda {|risk, user| !risk.new_record? && user.allowed_to?(:set_notes_private, risk.project)}

  # Safely sets attributes
  # Should be called from controllers instead of #attributes=
  # attr_accessible is too rough because we still want things like
  # Issue.new(:project => foo) to work
  def safe_attributes=(attrs, user=User.current)
    @attributes_set_by = user
    return unless attrs.is_a?(Hash)

    attrs = attrs.deep_dup

    if attrs['custom_field_values'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
      attrs['custom_field_values'].select! {|k, v| editable_custom_field_ids.include?(k.to_s)}
    end

    if attrs['custom_fields'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
      attrs['custom_fields'].select! {|c| editable_custom_field_ids.include?(c['id'].to_s)}
    end

    # mass-assignment security bypass
    assign_attributes attrs, :without_protection => true
  end

  def status_label
    l(("label_status_" + status).to_sym)
  end

  def magnitude
    return unless probability && impact

    index = (impact * (probability / 100.0) * (RISK_MAGNITUDE.count / 100.0)).round.to_i
    level = RISK_MAGNITUDE[index]

    l(("label_risk_level_" + level).to_sym)
  end

  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)

    # We don't want any notifications to be sent since Journal only support issues notifications
    @current_journal.notify = false
  end

  # Returns the current journal or nil if it's not initialized
  def current_journal
    @current_journal
  end

  # Clears the current journal
  def clear_journal
    @current_journal = nil
  end

  # Returns the names of attributes that are journalized when updating the issue
  def journalized_attribute_names
    Risk.column_names - %w(id created_on updated_on closed_on)
  end

  # Returns the id of the last journal or nil
  def last_journal_id
    if new_record?
      nil
    else
      journals.maximum(:id)
    end
  end

  # Returns a scope for journals that have an id greater than journal_id
  def journals_after(journal_id)
    scope = journals.reorder("#{Journal.table_name}.id ASC")
    if journal_id.present?
      scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
    end
    scope
  end

  # Returns the journals that are visible to user with their index
  # Used to display the issue history
  def visible_journals_with_index(user=User.current)
    result = journals.
      preload(:details).
      preload(:user => :email_address).
      reorder(:created_on, :id).to_a

    result.each_with_index {|j,i| j.indice = i+1}

    unless user.allowed_to?(:view_private_notes, project)
      result.select! do |journal|
        !journal.private_notes? || journal.user == user
      end
    end

    Journal.preload_journals_details_custom_fields(result)
    result.select! {|journal| journal.notes? || journal.visible_details.any?}
    result
  end

  # Return true if the risk is closed, otherwise false
  def closed?
    closed_on.present?
  end

  # Return true if the risk is being closed
  def closing?
    if new_record?
      closed?
    else
      closed_on_changed? && closed?
    end
  end

  # Users the risk request can be assigned to
  def assignable_users
    users = project.assignable_users.to_a
    users << author if author && author.active?
    if assigned_to_id_was.present? && assignee = Principal.find_by_id(assigned_to_id_was)
      users << assignee
    end
    users.uniq.sort
  end

  def assigned_to_users
    return [] unless assigned_to

    assigned_to.is_a?(Group) ? assigned_to.users : [assigned_to]
  end

  # Returns the previous assignee (user or group) if changed
  def assigned_to_was
    # assigned_to_id_was is reset before after_save callbacks
    user_id = @previous_assigned_to_id || assigned_to_id_was
    if user_id && user_id != assigned_to_id
      @assigned_to_was ||= Principal.find_by_id(user_id)
    end
  end

  def assigned_to_was_users
    return [] unless assigned_to_was

    assigned_to_was.is_a?(Group) ? assigned_to_was.users : [assigned_to_was]
  end

  def last_updated_by
    if @last_updated_by
      @last_updated_by.presence
    else
      journals.reorder(:id => :desc).first.try(:user)
    end
  end

  def last_notes
    if @last_notes
      @last_notes
    else
      journals.where.not(notes: '').reorder(:id => :desc).first.try(:notes)
    end
  end

  # Preloads users who updated last a collection of issues
  def self.load_visible_last_updated_by(risks, user=User.current)
    if risks.any?
      risk_ids = risks.map(&:id)
      journal_ids = Journal.joins(risk: :project).
        where(:journalized_type => 'Risk', :journalized_id => risk_ids).
        where(Journal.visible_notes_condition(user, :skip_pre_condition => true)).
        group(:journalized_id).
        maximum(:id).
        values
      journals = Journal.where(:id => journal_ids).preload(:user).to_a

      risks.each do |risk|
        journal = journals.detect {|j| j.journalized_id == risk.id}
        risk.instance_variable_set("@last_updated_by", journal.try(:user) || '')
      end
    end
  end

  # Preloads visible last notes for a collection of risks
  def self.load_visible_last_notes(risks, user=User.current)
    if risks.any?
      risk_ids = risks.map(&:id)
      journal_ids = Journal.joins(risk: :project).
        where(:journalized_type => 'Risk', :journalized_id => risk_ids).
        where(Journal.visible_notes_condition(user, :skip_pre_condition => true)).
        where.not(notes: '').
        group(:journalized_id).
        maximum(:id).
        values
      journals = Journal.where(:id => journal_ids).to_a

      risks.each do |risk|
        journal = journals.detect {|j| j.journalized_id == risk.id}
        risk.instance_variable_set("@last_notes", journal.try(:notes) || '')
      end
    end
  end

  # Returns a string of css classes that apply to the issue
  def css_classes(user=User.current)
    s = "risk"
    s << ' closed' if closed?
    s << ' created-by-me' if author_id == user.id
    s << ' assigned-to-me' if assigned_to_id == user.id
    s << ' assigned-to-my-group' if user.groups.any? {|g| g.id == assigned_to_id}
  end

  # Finds an issue that can be referenced by the commit message
  def find_referenced_issue_by_id(id)
    return nil if id.blank?

    # TODO - Add a Setting `Setting.risk_cross_project_ref?` and verifiy if the issue can be linked
    Issue.find_by_id(id.to_i)
  end

  private

  def user_permission?(user, permission)
    if project && !project.active?
      perm = Redmine::AccessControl.permission(permission)
      return false unless perm && perm.read?
    end

    user.allowed_to?(permission, project)
  end

  # Make sure updated_on is updated when adding a note and set updated_on now
  # so we can set closed_on with the same value on closing
  def force_updated_on_change
    if @current_journal || changed?
      self.updated_on = current_time_from_proper_timezone
      if new_record?
        self.created_on = updated_on
      end
    end
  end

  # Callback for setting closed_on when the issue is closed.
  # The closed_on attribute stores the time of the last closing
  # and is preserved when the issue is reopened.
  def update_closed_on
    if closing?
      self.closed_on = updated_on
    end
  end

  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if current_journal
      current_journal.save
    end
  end

  # Stores the previous assignee so we can still have access
  # to it during after_save callbacks (assigned_to_id_was is reset)
  def set_assigned_to_was
    @previous_assigned_to_id = assigned_to_id_was
  end

  # Clears the previous assignee at the end of after_save callbacks
  def clear_assigned_to_was
    @assigned_to_was = nil
    @previous_assigned_to_id = nil
  end

  # Called after a relation is added
  def relation_added(issue)
    journalize_action(
      :property  => 'relation',
      :prop_key  => 'relates',
      :value => issue.try(:id)
    )
  end

  # Called after a relation is removed
  def relation_removed(issue)
    journalize_action(
      :property  => 'relation',
      :prop_key  => 'relates',
      :old_value => issue.try(:id)
    )
  end

  def journalize_action(*args)
    return unless current_journal

    current_journal.details << JournalDetail.new(*args)
    current_journal.save
  end
end
