#!/usr/bin/env zsh
# Zsh completion for gitcrew
#
# Install:
#   source <(gitcrew --completions zsh)
#   # or copy to an fpath directory (e.g., ~/.zsh/completions/_gitcrew)

#compdef gitcrew

_gitcrew() {
    local -a commands
    commands=(
        'init:Initialize .agent/ directory in current repo'
        'spawn:Spawn an AI agent session'
        'monitor:Show live agent activity dashboard'
        'task:Manage the agent task board'
        'doctor:Diagnose repo readiness for agents'
        'hooks:Manage git hooks (pre-push tests)'
        'log:Append to or view agent log'
        'status:Quick overview of agent team status'
    )

    _arguments -C \
        '1:command:->command' \
        '*::arg:->args'

    case "$state" in
        command)
            _describe -t commands 'gitcrew command' commands
            _arguments \
                '--help[Show help]' \
                '--version[Show version]'
            ;;
        args)
            case "${words[1]}" in
                init)
                    _arguments \
                        '--force[Overwrite existing .agent/ directory]' \
                        '--no-roles[Skip role templates]' \
                        '--no-docker[Skip Docker files]' \
                        '--no-hooks[Skip git hooks setup]'
                    ;;
                spawn)
                    _arguments \
                        '1:agent-name:' \
                        '2:role:(feature bugfix refactor review)' \
                        '--cli[CLI tool to use]:cli:(claude cursor aider codex)' \
                        '--model[Model to use]:model:' \
                        '--docker[Run in Docker container]' \
                        '--dry-run[Show prompt without running]' \
                        '--once[Run once then exit]'
                    ;;
                task)
                    local -a subcmds
                    subcmds=(
                        'list:Show all tasks'
                        'add:Add a new task to the backlog'
                        'lock:Lock a task for an agent'
                        'done:Mark a task as done'
                        'unlock:Release a locked task'
                        'import:Import tasks from a file'
                        'clear-done:Archive completed tasks'
                    )
                    _describe -t subcmds 'task subcommand' subcmds
                    ;;
                monitor)
                    _arguments \
                        '--interval[Refresh interval in seconds]:seconds:' \
                        '--once[Show once and exit]'
                    ;;
                doctor)
                    _arguments \
                        '--fix[Attempt to auto-fix issues]'
                    ;;
                hooks)
                    _arguments \
                        '--remove[Remove git hooks]'
                    ;;
                log)
                    _arguments \
                        '1:subcommand:(show)' \
                        '--lines[Number of lines to show]:count:'
                    ;;
            esac
            ;;
    esac
}

_gitcrew "$@"
