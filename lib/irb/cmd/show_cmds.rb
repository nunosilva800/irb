# frozen_string_literal: true

require "stringio"
require_relative "nop"
require_relative "../pager"

module IRB
  # :stopdoc:

  module ExtendCommand
    class ShowCmds < Nop
      category "IRB"
      description "List all available commands and their description."

      def execute(*args)
        output = StringIO.new

        commands_info = IRB::ExtendCommandBundle.all_commands_info

        if irb_context.with_debugger
          commands_info.delete_if do |cmd|
            # Remove debugging commands and `help` because they are delegated to the debugger
            cmd[:category] == "Debugging" || cmd[:display_name] == :help
          end
        end

        generate_section("[Commands]", commands_info, output)

        helpers_info = IRB::HelperMethod.all_helper_methods_info
        generate_section("[Helper Methods]", helpers_info, output)

        # Append the debugger help at the end
        if irb_context.with_debugger
          output.puts(Color.colorize("[Debugging Commands] (from debug.gem)", [:BOLD]) + "\n\n")
          output.puts DEBUGGER__.help
        end

        Pager.page_content(output.string)
      end

      private

      def generate_section(title, entries, output)
        output.puts(Color.colorize(title, [:BOLD]) + "\n\n")

        entries_grouped_by_categories = entries.group_by { |cmd| cmd[:category] }
        longest_name_length = entries.map { |c| c[:display_name].length }.max

        entries_grouped_by_categories.each do |category, entries|
          output.puts Color.colorize(category, [:BOLD])

          entries.each do |entry|
            output.puts "  #{entry[:display_name].to_s.ljust(longest_name_length)}    #{entry[:description]}"
          end

          output.puts
        end
      end
    end
  end

  # :startdoc:
end
