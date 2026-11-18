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
        # Category of the project that could not be saved by update_or_create_risk_categories
        attr_reader :invalid_risk_category

        # Returns the system wide and project specific risk categories, the system
        # categories overridden by the project being excluded. The categories
        # created for the project only come after the system categories.
        def risk_categories_available(include_inactive = false)
          t = RiskCategory.table_name
          scope = RiskCategory.where("#{t}.project_id IS NULL OR #{t}.project_id = ?", id)

          overridden_category_ids = risk_categories.pluck(:parent_id).compact
          if overridden_category_ids.any?
            scope = scope.where("#{t}.id NOT IN (?)", overridden_category_ids)
          end
          scope = scope.active unless include_inactive
          scope.reorder(
            Arel.sql("CASE WHEN #{t}.project_id IS NOT NULL AND #{t}.parent_id IS NULL THEN 1 ELSE 0 END"),
            "#{t}.position", "#{t}.id"
          )
        end

        # Creates or updates the project risk categories. Returns false, and
        # rolls back every change, if one of the categories can't be saved.
        def update_or_create_risk_categories(categories)
          @invalid_risk_category = nil
          transaction do
            categories.each do |id, category|
              next if update_or_create_risk_category(id, category)

              raise ActiveRecord::Rollback
            end
          end
          @invalid_risk_category.nil?
        end

        # Creates an override of a system category or updates a category of the
        # project. Only the categories specific to the project can be renamed.
        def update_or_create_risk_category(id, category_hash)
          if category_hash.respond_to?(:has_key?) && category_hash.has_key?('parent_id')
            create_risk_category_if_needed(category_hash)
          else
            category = risk_categories.find_by_id(id.to_i)
            return true unless category

            category_hash = category_hash.to_h.except('name', :name) unless category.project_specific?
            return true if category.update(category_hash)

            @invalid_risk_category = category
            false
          end
        end

        # Creates a new project category if it overrides a system category, and
        # moves the project risks to the new category. Returns false if the
        # category is not successfully saved.
        def create_risk_category_if_needed(category)
          return true unless category['parent_id']

          parent_category = RiskCategory.shared.find(category['parent_id'])
          category['name'] = parent_category.name
          category['position'] = parent_category.position
          category['custom_field_values'] ||= {}
          return true unless Enumeration.overriding_change?(category, parent_category)

          project_category = risk_categories.create(category)
          if project_category.new_record?
            @invalid_risk_category = project_category
            return false
          end

          Risk.where(:project_id => id, :category_id => parent_category.id).
            update_all(:category_id => project_category.id)
          true
        end
      end
    end
  end
end

unless Project.included_modules.include?(RedmineRisks::Patches::ProjectPatch)
  Project.send(:include, RedmineRisks::Patches::ProjectPatch)
end
