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
dnf install -y gcc g++ automake autoconf patch  
dnf install -y ncurses-devel wxGTK-devel wxBase
dnf install -y openssl-devel
dnf install -y libiodbc unixODBC-devel.x86_64
dnf install -y erlang-odbc.x86_64 erlang-xmerl
dnf install -y libxslt fop
dnf install -y java-25-openjdk-devel
dnf install -y postgresql postgresql-devel postgresql-server postgresql-contrib postgresql-docs
dnf install -y inotify-tools
rpm -i https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-fedora-repo-2-1.noarch.rpm
dnf remove postgresql-private-devel
dnf install -y pgadmin4-desktop
```

Setup PostgreSQL database:
```
postgresql-setup --initdb
systemctl start postgresql
systemctl enable postgresql

```

Configure user:
```
sudo -u postgres createuser "$USER"
sudo -u postgres psql -c "ALTER USER \"$USER\" WITH SUPERUSER ;"
sudo -u postgres psql -c "ALTER USER \"$USER\" WITH CREATEDB CREATEROLE ;"

```

Edit `/var/lib/pgsql/data/pg_hba.conf`:

Change last column for loopback addresses from `ident` to `trust`
```
# IPv4 local connections:
host    all             all             127.0.0.1/32            ident
# IPv6 local connections:
host    all             all             ::1/128                 ident

```

This can also be done with `sed`:
```
sed -r -i -e 's/^(host[ \t]+all[ \t]+all[ \t]+(127\.0\.0\.1\/32|::1\/128)[ \t]+)ident.*$/\1trust/g' /var/lib/pgsql/data/pg_hba.conf
```

Optionally you may need to modify `/var/lib/pgsql/data/postgresql.conf` `listen_addresses` to add other network addresses, like podman containers.


Download and install Visual Studio Code

Download and install `asdf`:

```
wget https://github.com/asdf-vm/asdf/releases/download/v0.19.0/asdf-v0.19.0-linux-amd64.tar.gz
tar -xvf asdf-v0.19.0-linux-amd64.tar.gz -C /usr/local/bin/ 
```

Add the following lines to `.bashrc`:
```
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
. <(asdf completion bash)
```


Add ASDF plugins:
```
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add python
```

Navigate to bindepot project and install tools:
```
cd bindepot
asdf install
```

On the first installation it will take some time to build erlang and elixir.


