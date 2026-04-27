# Bindepot

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix


# Setting up dev environment
## Fedora Linux 42 KDE Plasma

Assuming a fresh Linux installation.


Install core tools and PostgreSQL.
```
dnf install -y git
dnf install -y gcc g++ automake autoconf
dnf install -y ncurses-devel wxGTK-devel wxBase
dnf install -y openssl-devel
dnf install -y libiodbc unixODBC-devel.x86_64 erlang-odbc.x86_64
dnf install -y libxslt fop
dnf install -y java-25-openjdk-devel
dnf install -y postgresql postgresql-devel postgresql-server postgresql-contrib postgresql-docs
dnf install -y inotify-tools
rpm -i https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-fedora-repo-2-1.noarch.rpm
dnf remove postgresql-private-devel
dnf install -y pgadmin4-desktop
```

Download and install Visual Studio Code

Download and install `asdf`:

```
wget https://github.com/asdf-vm/asdf/releases/download/v0.19.0/asdf-v0.19.0-linux-amd64.tar.gz
tar -xvf asdf-v0.19.0-linux-amd64.tar.gz -C /usr/local/bin/ 
```

Add ASDF plugins:
```
asdf plugin add erlang
asdf plugin add elixir
```

Navigate to bindepot project and install tools:
```
cd bindepot
asdf install
```

On the first installation it will take some time to build erlang and elixir.


