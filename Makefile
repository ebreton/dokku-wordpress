DOKKU_HOST:=breton.ch
DOKKU_MARIADB_SERVICE:=mysql

LOCAL_BACKUP_PATH:=~/var/dokku_backup

###
# ONE OFF

init-host:
	# setup MariaDB
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-mariadb.git mariadb
	ssh -t dokku@breton.ch mariadb:create ${DOKKU_MARIADB_SERVICE}
	# pull initial docker image for Wordpress
	docker pull wordpress:4.9-php5.6-apache
	# and tag it on host to make it available to dokku
	docker tag wordpress:4.9-php5.6-apache dokku/wordpress:4.9-fpm-alpine

###
# CREATE & DESTROY

create: validate-app
	# create an app and set environment variable+port before 1st deployment
	ssh -t dokku@breton.ch apps:create ${NAME}
	ssh -t dokku@breton.ch config:set ${NAME} WORDPRESS_DB_HOST=dokku-mariadb-${DOKKU_MARIADB_SERVICE}
	# link with DB
	ssh -t dokku@breton.ch mariadb:link ${DOKKU_MARIADB_SERVICE} ${NAME}
	# push app from docker up image wordpress:alpine
	git push ${NAME} master
	# switch to HTTPs
	ssh -t dokku@breton.ch letsencrypt ${NAME}
	# mount volume for images
	ssh -t dokku@breton.ch storage:mount ${NAME} /var/lib/dokku/data/storage/${NAME}:/var/www
	ssh -t dokku@breton.ch ps:restart ${NAME}

destroy: validate-app
	ssh -t dokku@breton.ch apps:destroy ${NAME}
	git remote remove ${NAME}

###
# MONITORING

apps:
	ssh -t dokku@breton.ch apps:report ${NAME}

domains:
	ssh -t dokku@breton.ch domains:report ${NAME}

proxy:
	ssh -t dokku@breton.ch proxy:report ${NAME}

storage:
	ssh -t dokku@breton.ch storage:report ${NAME}

###
# BACKUP & RESTORE

backup-all:
	[ -d $(LOCAL_BACKUP_PATH) ] || mkdir -p $(LOCAL_BACKUP_PATH)
	rsync -av ${DOKKU_HOST}:/var/lib/dokku/data/storage/ ${LOCAL_BACKUP_PATH}

backup: validate-app
	[ -d $(LOCAL_BACKUP_PATH) ] || mkdir -p $(LOCAL_BACKUP_PATH)
	rsync -av ${DOKKU_HOST}:/var/lib/dokku/data/storage/${NAME} ${LOCAL_BACKUP_PATH}/

restore: validate-app
	rsync -av ${LOCAL_BACKUP_PATH}/${NAME} ${DOKKU_HOST}:/var/lib/dokku/data/storage/

###
# INPUT VALIDATION

validate-app:
ifndef NAME
	$(error NAME is not set)
endif
