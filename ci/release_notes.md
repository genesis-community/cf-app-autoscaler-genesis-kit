# Attention Required

* The 1.0.0 version of the kit was released without allocating the local
postgres database node a persistent disk. If you are not using an external
database, this can easily lead to loss of autoscaler service data. This is
fixed in this version of the kit - please follow the following instructions
to avoid data loss. Do not panic. Everything is going to be okay.

## Taking a Backup of the Existing Database

Make sure you take this backup before upgrading the kit!

* `bosh ssh` onto the `postgres_autoscaler` of the deployment.
* become root with `sudo -i`
* Run the following to take a backup `/var/vcap/packages/postgres-9.6.6/bin/pg_dumpall -U vcap >/tmp/pg_dump.sql`
* Fetch the backup from the VM by exiting the VM and running `bosh -e <envname> -d <depname> scp postgres_autoscaler:/tmp/pg_dump.sql ~/autoscaler_pg_dump.sql`

## Upgrade the Kit

* Bump the kit number in your environment file to this version and deploy it with `genesis deploy <envname>`

## Restore the Database

Now you have a fresh, empty database. Let's put the data back.

* Upload the backup you took to the VM with `bosh -e <envname> -d <depname> scp ~/autoscaler_pg_dump.sql postgres_autoscaler:/tmp/`
* SSH onto the `postgres_autoscaler` VM with `bosh ssh`
* Become root with `sudo -i`
* Perform the restore with `/var/vcap/packages/postgres-9.6.6/bin/psql -U vcap postgres </tmp/autoscaler_pg_dump.sql`

After this, service should be restored and the database should have a persistent disk.

# Additional Features

* The kit will now generate 10 year CA certs when creating a new deployment.