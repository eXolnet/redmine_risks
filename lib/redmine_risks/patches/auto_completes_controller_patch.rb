# frozen_string_literal: true

module RedmineRisks
  module Patches
    module AutoCompletesControllerPatch
      def risks
        risks = []
        q = (params[:q] || params[:term]).to_s.strip
        if q.present?
          if q =~ /\A#?(\d+)\z/
            risks << Risk.find($1.to_i)
          end
          risks += Risk.like(q).order(:id => :desc).limit(10).to_a
          risks.compact!
        end
    
        render :json => format_risks_json(risks)
      end

      def format_risks_json(risks)
        risks.map do |risk|
          {
            'id' => risk.id,
            'label' => "#{risk.project} ##{risk.id}: #{risk.subject.to_s.truncate(255)}",
            'value' => risk.id
          }
        end
      end      
    end
  end
end

unless AutoCompletesController.included_modules.include?(RedmineRisks::Patches::AutoCompletesControllerPatch)
  AutoCompletesController.send(:include, RedmineRisks::Patches::AutoCompletesControllerPatch)
end
