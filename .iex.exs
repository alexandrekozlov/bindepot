IEx.configure(auto_reload: true)
alias Bindepot.Core.Repositories
alias Bindepot.Pypi.RepoIndex
local = Repositories.get_by_name("pypi-local")
remote = Repositories.get_by_name("pypi-remote")
virtual = Repositories.get_by_name("pypi-virtual")
