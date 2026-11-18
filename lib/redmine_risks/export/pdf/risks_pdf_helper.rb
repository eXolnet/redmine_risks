module RedmineRisks
  module Export
    module PDF
      # PDF exports of risks, modelled after Redmine::Export::PDF::IssuesPdfHelper.
      # Cell values are built with QueriesHelper#csv_content so the PDF shows the
      # same translated labels (probability, impact, magnitude, strategy, status)
      # as the CSV export, custom field columns included.
      module RisksPdfHelper
        # Returns a PDF string of a single risk
        def risk_to_pdf(risk, journals = [])
          pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language)
          title = "#{risk.project} - #{l(:label_risk)} ##{risk.id}"
          pdf.set_title(title)
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.add_page

          pdf.SetFontStyle('B', 11)
          pdf.RDMMultiCell(190, 5, title)
          pdf.RDMMultiCell(190, 5, risk.subject.to_s)
          pdf.SetFontStyle('', 8)
          pdf.RDMMultiCell(190, 5, "#{format_time(risk.created_on)} - #{risk.author}")
          pdf.ln

          risk_pdf_attributes(risk).each do |label, value|
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(45, 5, "#{label}:")
            pdf.SetFontStyle('', 9)
            pdf.RDMMultiCell(145, 5, value.to_s.presence || '-')
          end

          [:description, :treatments, :lessons].each do |attribute|
            next if risk.send(attribute).blank?

            pdf.ln
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(190, 5, l("field_#{attribute}"), 'B', 1)
            pdf.SetFontStyle('', 9)
            pdf.RDMwriteFormattedCell(190, 5, '', '', pdf_format_text(risk, attribute), [], '')
          end

          related_issues = risk.issues.visible.to_a
          if related_issues.any?
            pdf.ln
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(190, 5, l(:label_related_issues), 'B', 1)
            pdf.SetFontStyle('', 8)
            related_issues.each do |issue|
              pdf.RDMMultiCell(190, 5, "#{issue.tracker} ##{issue.id} (#{issue.status}): #{issue.subject}")
            end
          end

          if journals.present?
            pdf.ln
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(190, 5, l(:label_history), 'B', 1)
            journals.each do |journal|
              pdf.SetFontStyle('B', 8)
              journal_title = "##{journal.indice} - #{format_time(journal.created_on)} - #{journal.user}"
              journal_title += " (#{l(:field_private_notes)})" if journal.private_notes?
              pdf.RDMCell(190, 5, journal_title, 0, 1)
              pdf.SetFontStyle('I', 8)
              risk_details_to_strings(journal.visible_details, true).each do |string|
                pdf.RDMMultiCell(190, 5, "- #{string}")
              end
              if journal.notes?
                pdf.SetFontStyle('', 8)
                pdf.RDMwriteFormattedCell(190, 5, '', '', pdf_format_text(journal, :notes), [], '')
              end
              pdf.ln
            end
          end

          pdf.output
        end

        # Returns a PDF string of a list of risks, following the columns, sort
        # and grouping of the query
        def risks_to_pdf(risks, project, query)
          pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language, 'L')
          title = query.new_record? ? l(:label_risks) : query.name
          title = "#{project} - #{title}" if project
          pdf.set_title(title)
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.set_auto_page_break(false)
          pdf.add_page('L')

          page_height   = pdf.get_page_height
          page_width    = pdf.get_page_width
          left_margin   = pdf.get_original_margins['left']
          right_margin  = pdf.get_original_margins['right']
          bottom_margin = pdf.get_footer_margin
          row_height    = 4
          table_width   = page_width - right_margin - left_margin

          rows = risks.map {|risk| risk_pdf_row_values(risk, query)}
          col_width = risks_pdf_col_widths(rows, query, table_width, pdf)

          pdf.SetFontStyle('B', 11)
          pdf.RDMCell(190, 8, title)
          pdf.ln

          risks_pdf_table_header(pdf, query, col_width) if col_width.any?
          previous_group = false
          result_count_by_group = query.grouped? ? query.result_count_by_group : {}

          risks.each_with_index do |risk, index|
            if query.grouped? && (group = query.group_by_column.group_value(risk)) != previous_group
              group_label = group.blank? ? l(:label_none) : risk_group_label(query, risk, group.to_s).to_s.dup
              group_label << " (#{result_count_by_group[group]})"
              pdf.SetFontStyle('B', 10)
              pdf.bookmark group_label, 0, -1
              pdf.RDMCell(table_width, row_height * 2, group_label, 'LR', 1, 'L')
              pdf.SetFontStyle('', 8)
              previous_group = group
            end

            if col_width.any?
              col_values = rows[index]
              base_y     = pdf.get_y
              max_height = get_issues_to_pdf_write_cells(pdf, col_values, col_width)
              if max_height > page_height - base_y - bottom_margin
                pdf.add_page('L')
                risks_pdf_table_header(pdf, query, col_width)
                base_y = pdf.get_y
              end

              issues_to_pdf_write_cells(pdf, col_values, col_width, max_height)
              pdf.set_y(base_y + max_height)
            end

            query.block_columns.each do |column|
              text = risk_pdf_block_text(risk, column)
              next if text.blank?

              pdf.set_x(left_margin)
              pdf.set_auto_page_break(true, bottom_margin)
              pdf.SetFontStyle('B', 9)
              pdf.RDMCell(0, 5, column.caption, 'LRT', 1)
              pdf.SetFontStyle('', 9)
              pdf.RDMwriteFormattedCell(0, 5, '', '', text, [], 'LRB')
              pdf.set_auto_page_break(false)
            end
          end

          if risks.size == Setting.issues_export_limit.to_i
            pdf.SetFontStyle('B', 10)
            pdf.RDMCell(0, row_height, '...')
          end

          pdf.output
        end

        private

        def risk_pdf_attributes(risk)
          attributes = [
            [l(:field_status), format_risk_status(risk.status)],
            [l(:field_assigned_to), risk.assigned_to],
            [l(:field_category), risk.category],
            [l(:field_probability), format_risk_probability(risk.probability)],
            [l(:field_impact), format_risk_impact(risk.impact)],
            [l(:field_magnitude), risk.magnitude],
            [l(:field_strategy), format_risk_strategy(risk.strategy)]
          ]

          risk.visible_custom_field_values.each do |custom_value|
            attributes << [custom_value.custom_field.name, show_value(custom_value, false)]
          end

          attributes
        end

        def risk_pdf_row_values(risk, query)
          query.inline_columns.map {|column| csv_content(column, risk).to_s}
        end

        def risk_pdf_block_text(risk, column)
          if column.is_a?(QueryCustomFieldColumn)
            custom_value = risk.visible_custom_field_values.detect {|v| v.custom_field_id == column.custom_field.id}
            return if custom_value.nil?

            text = show_value(custom_value, false)
            custom_value.custom_field.full_text_formatting? ? textilizable(text.to_s, :only_path => false) : ERB::Util.html_escape(text)
          elsif risk.respond_to?(column.name) && risk.class.column_names.include?(column.name.to_s)
            pdf_format_text(risk, column.name)
          else
            textilizable(column.value_object(risk).to_s, :only_path => false, :headings => false)
          end
        end

        # Distributes the table width between the inline columns according to
        # the average width of their values, without going below the width of
        # the longest word of their caption.
        def risks_pdf_col_widths(rows, query, table_width, pdf)
          columns = query.inline_columns
          return [] if columns.empty?

          padding = pdf.get_margins['cell'] * 2

          pdf.SetFontStyle('B', 8)
          min_widths = columns.map do |column|
            (column.caption.to_s.split.map {|word| pdf.get_string_width(word)}.max || 0) + padding
          end

          pdf.SetFontStyle('', 8)
          widths = columns.each_index.map do |i|
            values = rows.map {|row| pdf.get_string_width(row[i]) + padding}
            average = values.empty? ? 0 : values.sum / values.size
            [average, min_widths[i]].max.clamp(0, table_width / 3.0)
          end

          ratio = table_width / widths.sum
          widths.map {|width| width * ratio}
        end

        def risks_pdf_table_header(pdf, query, col_width)
          pdf.SetFontStyle('B', 8)
          pdf.set_fill_color(230, 230, 230)

          base_x     = pdf.get_x
          base_y     = pdf.get_y
          max_height = get_issues_to_pdf_write_cells(pdf, query.inline_columns, col_width, true)

          issues_to_pdf_write_cells(pdf, query.inline_columns, col_width, max_height, true)
          pdf.set_xy(base_x, base_y + max_height)

          pdf.SetFontStyle('', 8)
          pdf.set_fill_color(255, 255, 255)
        end
      end
    end
  end
end
