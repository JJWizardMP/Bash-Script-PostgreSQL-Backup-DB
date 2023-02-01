#Download base image ubuntu 20.04
FROM ubuntu:20.04
# Create the file repository configuration:
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# Import the repository signing key:
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
# Update the package lists:
RUN apt-get update
# Install the latest version of PostgreSQL.
# If you want a specific version, use 'postgresql-14' or similar instead of 'postgresql':
RUN apt-get -y install postgresql
COPY . ./backupVCM
