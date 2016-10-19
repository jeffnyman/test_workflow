require "test_workflow/version"

require "data_builder"

module TestWorkflow
  module Paths
    def paths
      @paths
    end

    def paths=(path)
      @paths = path
      raise("You must provide a default workflow path") unless paths[:default]
      @paths
    end
  end

  def self.included(caller)
    caller.extend Paths
    @caller = caller
  end

  def self.caller
    @caller
  end

  # Provides an execution path for a given workflow path, using a specific
  # definition that is part of that workflow path.
  def path_to(context, keys = { using: :default, visit: false }, &block)
    keys[:using] = :default unless keys[:using]
    keys[:visit] = false unless keys[:visit]

    path, path_goal = path_trail(keys, context)

    return on(context, &block) if path_goal == -1

    path_start = keys[:from] ? path_start_point(path, keys) : 0
    execute_path(path[path_start..path_goal], keys[:visit])

    on(context, &block)
  end

  alias path_up_to     path_to
  alias workflow_to    path_to
  alias workflow_up_to path_to

  # Provides an execution path that starts execution of a given path
  # from the standpoint of the "current context", which is something
  # that must be set as part of execution logic.
  def continue_path_to(context, keys = { using: :default }, &block)
    path = workflow_path_for(keys)
    path_start = find_index_for(path, @current_context.class)
    path_end = find_index_for(path, context) - 1

    if path_start == path_end
      execute_path([path[path_start]], false)
    else
      execute_path(path[path_start..path_end], false)
    end

    on(context, &block)
  end

  # Provides an execution path for an entire workflow path.
  def entire_path(keys = { using: :default, visit: false })
    path_workflow = workflow_path_for(keys)
    execute_path(path_workflow[0..-1], keys[:visit])
  end

  alias run_entire_path entire_path
  alias run_full_path   entire_path

  private

  def path_trail(keys, context)
    path = workflow_path_for(keys)
    goal = find_index_for(path, context) - 1
    [path, goal]
  end

  def path_start_point(path, keys)
    path.find_index { |item| item[0] == keys[:from] }
  end

  def workflow_path_for(keys)
    path = TestWorkflow.caller.paths[keys[:using]]
    raise("The path named '#{keys[:using]}' was not found.") unless path
    path
  end

  def execute_path(path, visit)
    path.each do |definition, action, *args|
      context = visit ? visit(definition) : on(definition)
      visit = false

      unless context.respond_to?(action)
        raise("Path action '#{action}' not defined on '#{definition}'.")
      end

      context.__send__ action unless args
      context.__send__ action, *args if args
    end
  end

  def find_index_for(path, context)
    path.find_index { |item| item[0] == context }
  end
end
