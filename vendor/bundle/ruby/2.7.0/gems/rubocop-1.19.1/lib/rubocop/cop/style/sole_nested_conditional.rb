# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # If the branch of a conditional consists solely of a conditional node,
      # its conditions can be combined with the conditions of the outer branch.
      # This helps to keep the nesting level from getting too deep.
      #
      # @example
      #   # bad
      #   if condition_a
      #     if condition_b
      #       do_something
      #     end
      #   end
      #
      #   # good
      #   if condition_a && condition_b
      #     do_something
      #   end
      #
      # @example AllowModifier: false (default)
      #   # bad
      #   if condition_a
      #     do_something if condition_b
      #   end
      #
      # @example AllowModifier: true
      #   # good
      #   if condition_a
      #     do_something if condition_b
      #   end
      #
      class SoleNestedConditional < Base
        include RangeHelp
        extend AutoCorrector

        MSG = 'Consider merging nested conditions into outer `%<conditional_type>s` conditions.'

        def self.autocorrect_incompatible_with
          [Style::NegatedIf, Style::NegatedUnless]
        end

        def on_if(node)
          return if node.ternary? || node.else? || node.elsif?

          if_branch = node.if_branch
          return if use_variable_assignment_in_condition?(node.condition, if_branch)
          return unless offending_branch?(if_branch)

          message = format(MSG, conditional_type: node.keyword)
          add_offense(if_branch.loc.keyword, message: message) do |corrector|
            autocorrect(corrector, node, if_branch)
          end
        end

        private

        def use_variable_assignment_in_condition?(condition, if_branch)
          assigned_variables = assigned_variables(condition)

          assigned_variables && if_branch&.if_type? &&
            assigned_variables.include?(if_branch.condition.source)
        end

        def assigned_variables(condition)
          assigned_variables = condition.assignment? ? [condition.children.first.to_s] : []

          assigned_variables + condition.descendants.select(&:assignment?).map do |node|
            node.children.first.to_s
          end
        end

        def offending_branch?(branch)
          return false unless branch

          branch.if_type? &&
            !branch.else? &&
            !branch.ternary? &&
            !(branch.modifier_form? && allow_modifier?)
        end

        def autocorrect(corrector, node, if_branch)
          corrector.wrap(node.condition, '(', ')') if node.condition.or_type?

          correct_from_unless_to_if(corrector, node) if node.unless?

          and_operator = if_branch.unless? ? ' && !' : ' && '
          if if_branch.modifier_form?
            correct_for_guard_condition_style(corrector, node, if_branch, and_operator)
          else
            correct_for_basic_condition_style(corrector, node, if_branch, and_operator)
            correct_for_comment(corrector, node, if_branch)
          end
        end

        def correct_from_unless_to_if(corrector, node)
          corrector.replace(node.loc.keyword, 'if')

          condition = node.condition
          if condition.send_type? && condition.comparison_method? && !condition.parenthesized?
            corrector.wrap(node.condition, '!(', ')')
          else
            corrector.insert_before(node.condition, '!')
          end
        end

        def correct_for_guard_condition_style(corrector, node, if_branch, and_operator)
          outer_condition = node.condition
          correct_outer_condition(corrector, outer_condition)

          condition = if_branch.condition
          corrector.insert_after(outer_condition, replacement_condition(and_operator, condition))

          range = range_between(if_branch.loc.keyword.begin_pos, condition.source_range.end_pos)
          corrector.remove(range_with_surrounding_space(range: range, newlines: false))
          corrector.remove(if_branch.loc.keyword)
        end

        def correct_for_basic_condition_style(corrector, node, if_branch, and_operator)
          range = range_between(
            node.condition.source_range.end_pos, if_branch.condition.source_range.begin_pos
          )
          corrector.replace(range, and_operator)
          corrector.remove(range_by_whole_lines(node.loc.end, include_final_newline: true))
          corrector.wrap(if_branch.condition, '(', ')') if wrap_condition?(if_branch.condition)
        end

        def correct_for_comment(corrector, node, if_branch)
          return if config.for_cop('Style/IfUnlessModifier')['Enabled']

          comments = processed_source.ast_with_comments[if_branch]
          comment_text = comments.map(&:text).join("\n") << "\n"

          corrector.insert_before(node.loc.keyword, comment_text) unless comments.empty?
        end

        def correct_outer_condition(corrector, condition)
          return unless requrie_parentheses?(condition)

          end_pos = condition.loc.selector.end_pos
          begin_pos = condition.first_argument.source_range.begin_pos
          return if end_pos > begin_pos

          corrector.replace(range_between(end_pos, begin_pos), '(')
          corrector.insert_after(condition.last_argument.source_range, ')')
        end

        def requrie_parentheses?(condition)
          condition.send_type? && !condition.arguments.empty? && !condition.parenthesized? &&
            !condition.comparison_method?
        end

        def arguments_range(node)
          range_between(
            node.first_argument.source_range.begin_pos, node.last_argument.source_range.end_pos
          )
        end

        def wrap_condition?(node)
          node.and_type? || node.or_type? ||
            (node.send_type? && node.arguments.any? && !node.parenthesized?)
        end

        def replacement_condition(and_operator, condition)
          if wrap_condition?(condition)
            "#{and_operator}(#{condition.source})"
          else
            "#{and_operator}#{condition.source}"
          end
        end

        def allow_modifier?
          cop_config['AllowModifier']
        end
      end
    end
  end
end
