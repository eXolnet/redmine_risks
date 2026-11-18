require_dependency 'project'

module RedmineRisks
  module Patches
    module ProjectPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          # Project specific risk categories (overrides of the system categories).
          # delete_all is used so that categories still referenced by risks do not
          # prevent the project deletion (Enumeration#check_integrity).
          has_many :risk_categories, :class_name => 'RiskCategory', :dependent => :delete_all
        end
      end

      module InstanceMethods
        # Returns the system wide and project specific risk categories, the system
        # categories overridden by the project being excluded
        def risk_categories_available(include_inactive = false)
          t = RiskCategory.table_name
          scope = RiskCategory.where("#{t}.project_id IS NULL OR #{t}.project_id = ?", id)

          overridden_category_ids = risk_categories.pluck(:parent_id).compact
          if overridden_category_ids.any?
            scope = scope.where("#{t}.id NOT IN (?)", overridden_category_ids)
          end
          scope = scope.active unless include_inactive
          scope
        end

        # Creates or updates the project risk categories
        def update_or_create_risk_categories(categories)
          transaction do
            categories.each do |id, category|
              update_or_create_risk_category(id, category)
            end
          end
        end

        # Creates a new project specific category or updates an existing one
        def update_or_create_risk_category(id, category_hash)
          if category_hash.respond_to?(:has_key?) && category_hash.has_key?('parent_id')
            create_risk_category_if_needed(category_hash)
          else
            category = risk_categories.find_by_id(id.to_i)
            category.update(category_hash) if category
          end
        end

        # Creates a new project category if it overrides a system category, and
        # moves the project risks to the new category.
        #
        # Raises ActiveRecord::Rollback if the category is not successfully saved.
        def create_risk_category_if_needed(category)
          return unless category['parent_id']

          parent_category = RiskCategory.shared.find(category['parent_id'])
          category['name'] = parent_category.name
          category['position'] = parent_category.position
          category['custom_field_values'] ||= {}
          return unless Enumeration.overriding_change?(category, parent_category)

          project_category = risk_categories.create(category)
          if project_category.new_record?
            raise ActiveRecord::Rollback, "Overriding RiskCategory was not successfully saved"
          end

          Risk.where(:project_id => id, :category_id => parent_category.id).
            update_all(:category_id => project_category.id)
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineRisks::Patches::ProjectPatch)
  Project.send(:include, RedmineRisks::Patches::ProjectPatch)
end
