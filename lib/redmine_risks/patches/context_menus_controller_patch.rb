require_dependency 'context_menus_controller'

module RedmineRisks
  module Patches
    module ContextMenusControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          helper :risks

          def risks
            @risks = Risk.where(:id => params[:ids]).to_a

            unless @risks.present?
              render_404
              return
            end

            @risk_ids = @risks.map(&:id).sort
            @risk = @risks.first if @risks.size == 1

            @projects = @risks.collect(&:project).compact.uniq
            @assignables = @risks.map(&:assignable_users).reduce(:&)
            @safe_attributes = @risks.map(&:safe_attribute_names).reduce(:&)

            edit_allowed = @risks.all? {|t| t.editable?(User.current)}
            @can = {:edit => edit_allowed, :delete => edit_allowed}
            @back = back_url

            render :layout => false
          end
        end
      end

      module InstanceMethods
        #
      end
    end
  end
end

unless ContextMenusController.included_modules.include?(RedmineRisks::Patches::ContextMenusControllerPatch)
  ContextMenusController.send(:include, RedmineRisks::Patches::ContextMenusControllerPatch)
end
