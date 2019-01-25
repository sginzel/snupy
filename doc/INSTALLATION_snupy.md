# SNUPY Setup
## System requirements
```
sudo apt-get install -y gunzip gcc patch bzip2 gawk g++ make patch zlib1g-dev libyaml-dev libsqlite3-dev \
        sqlite3 autoconf libgmp-dev libgdbm-dev libncurses5-dev automake libtool bison pkg-config \
        libffi-dev libgmp-dev libreadline6-dev libssl-doc libssl-dev curl ca-certificates \
        libcurl4-openssl-dev libaprutil1-dev libapr1-dev libaprutil1-dev nano git vim \
        libmysqlclient-dev libreadline6 libreadline6-dev libxml2-dev libxml2
        
curl -L https://get.rvm.io | bash -s stable
/bin/bash -l -c "source /etc/profile.d/rvm.sh \
        && rvm install ruby-2.3.3 \
        && rvm --default use 2.3.3 \
        && rvm fetch ruby-2.3.3 \
        && rvm fetch ruby-2.3.3-head \
        && gem install bundler -v 1.16.0 --no-ri --no-rdoc"


```
## Download and Requirements
```
source /etc/profile.d/rvm.sh
cd /opt 
git clone https://github.com/sginzel/snupy.git
cd snupy
bundle install
echo "SnupyAgain::Application.config.secret_token = '$(pwgen -s 128 1)'" > config/initializers/secret_token.rb
```

## Setup Database
You will need to specify the database and credentials so Snupy knows where and how to store data. Use config/database.yml.dist as and example

Create config/database.yml that looks like this:
```
development:
  adapter: mysql2
  database: snupy_again_dev
  pool: 5
  host: HOST
  port: 3306
  username: USER
  password: PASS
  reconnect: true
  local_infile: true

# if you want to use the API features add a read-only user named API_USER to you database
# make sure it is only allowed to perform SELECT operations, because this provides the possibility
# to send SQL commands to the DB server from the web application.
development_api:
  adapter: mysql2
  database: snupy_again_dev
  pool: 5
  host: HOST
  port: 3306
  username: API_USER
  password: API_USER_PW
  reconnect: true
  local_infile: true


# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test:
  adapter: sqlite3
  database: db/test.sqlite3
  pool: 5
  timeout: 5000

production:
  adapter: mysql2
  database: snupy_again
  pool: 5
  host: HOST
  port: 3306
  username: USER
  password: PASS
  socket: /var/run/mysqld/mysqld.sock

production_api:
  adapter: mysql2
  database: snupy_again
  pool: 5
  host: HOST
  port: 3306
  username: API_USER
  password: API_USER_PW
  socket: /var/run/mysqld/mysqld.sock
```

Make sure USER has permission to create databases and that API_USER is only granted SELECT permisison. 
One way to do this is (using the same username and pw as in the example above):
```
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'USER'@'localhost' IDENTIFIED BY 'PASS';"
sudo mysql -e "GRANT SELECT ON *.* TO 'API_USER'@'localhost' IDENTIFIED BY 'API_USER_PW';"
```

```
# Set default users to be created when SNuPy is created
SNUPY_DEFAULT_USER_NAME="snupy"
SNUPY_DEFAULT_USER_FULLNAME="snupy admin"
SNUPY_DEFAULT_USER_EMAIL="none@example.com"

## setup development & production environment 
/bin/bash -c "source /etc/profile.d/rvm.sh \
        && bundle exec rake db:create \
        && bundle exec rake db:migrate \
        && bundle exec rake db:seed"
```
## Test your installation
``` 
# start snupy on your localhost
rails s
```
Now go to [localhost:3000](localhost:3000) and will be able to add users, project and upload new datasets. Follow the [AQuA modules](doc/INSTALLATION_aqua.md) setup instruction to get the necessary annotation tools setup. 
