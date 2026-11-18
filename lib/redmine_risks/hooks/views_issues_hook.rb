module RedmineRisks
  module Hooks
    class ViewsIssuesHook < Redmine::Hook::ViewListener
      render_on :view_issues_show_description_bottom, :partial => 'issues/risks'
    end
  end
end
