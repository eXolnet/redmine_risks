xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  journals = @journals.sort_by {|journal| [journal.created_on, journal.id]}.reverse

  xml.title   "#{@risk.project.name} - #{l(:label_risk)} ##{@risk.id}: #{@risk.subject}"
  xml.link    "rel" => "self", "href" => risk_url(@risk, :format => 'atom', :key => User.current.atom_key)
  xml.link    "rel" => "alternate", "href" => risk_url(@risk)
  xml.id      risk_url(@risk)
  xml.icon    favicon_url
  xml.updated((journals.first ? journals.first.created_on : @risk.updated_on).xmlschema)
  xml.author  { xml.name "#{Setting.app_title}" }
  xml.generator(:uri => Redmine::Info.url) { xml.text! Redmine::Info.app_name }

  journals.each do |journal|
    xml.entry do
      xml.title   "#{@risk.project.name} - #{l(:label_risk)} ##{@risk.id}: #{@risk.subject}"
      xml.link    "rel" => "alternate", "href" => risk_url(@risk, :anchor => "change-#{journal.id}")
      xml.id      risk_url(@risk, :journal_id => journal.id)
      xml.updated journal.created_on.xmlschema
      xml.author do
        xml.name journal.user.name
        xml.email(journal.user.mail) if journal.user.is_a?(User) && journal.user.mail.present? && !journal.user.pref.hide_mail
      end
      xml.content "type" => "html" do
        xml.text! '<ul>'
        risk_details_to_strings(journal.visible_details, false, :only_path => false).each do |string|
          xml.text! '<li>' + string + '</li>'
        end
        xml.text! '</ul>'
        xml.text! textilizable(journal, :notes, :only_path => false) unless journal.notes.blank?
      end
    end
  end
end
