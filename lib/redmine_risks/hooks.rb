module RedmineRisks
    class Hooks < Redmine::Hook::ViewListener
        render_on :view_issues_show_description_bottom, partial: 'issues/risk_relations'
    end
end
