DOKKU_HOST:=breton.ch
DOKKU_MARIADB_SERVICE:=mysql

LOCAL_BACKUP_PATH:=~/var/dokku_backup

###
# ONE OFF

init-host:
	# setup MariaDB
	ssh -t dokku@${DOKKU_HOST} mariadb:create ${DOKKU_MARIADB_SERVICE} || true
	# pull initial docker image for Wordpress
	ssh ${DOKKU_HOST} docker pull wordpress:4.9-php5.6-apache
	# and tag it on host to make it available to dokku
	ssh ${DOKKU_HOST} docker tag wordpress:4.9-php5.6-apache dokku/wordpress:4.9-fpm-alpine

###
# CREATE & DESTROY

create: validate-app
	# create an app and set environment variable+port before 1st deployment
	ssh -t dokku@${DOKKU_HOST} apps:create ${NAME}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WORDPRESS_DB_HOST=dokku-mariadb-${DOKKU_MARIADB_SERVICE}
	# link with DB
	ssh -t dokku@${DOKKU_HOST} mariadb:link ${DOKKU_MARIADB_SERVICE} ${NAME}
	# push app from docker up image wordpress:alpine
	git push ${NAME} master
	# switch to HTTPs
	ssh -t dokku@${DOKKU_HOST} letsencrypt ${NAME}
	# mount volume for images
	ssh -t dokku@${DOKKU_HOST} storage:mount ${NAME} /var/lib/dokku/data/storage/${NAME}:/var/www
	ssh -t dokku@${DOKKU_HOST} ps:restart ${NAME}

destroy: validate-app
	ssh -t dokku@${DOKKU_HOST} apps:destroy ${NAME}
	git remote remove ${NAME}

###
# MONITORING

apps:
	ssh -t dokku@${DOKKU_HOST} apps:report ${NAME}

domains:
	ssh -t dokku@${DOKKU_HOST} domains:report ${NAME}

proxy:
	ssh -t dokku@${DOKKU_HOST} proxy:report ${NAME}

storage:
	ssh -t dokku@${DOKKU_HOST} storage:report ${NAME}

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

###
# local testing

mariadb:
	docker run --rm --name maria -e MYSQL_ROOT_PASSWORD=secret -d mariadb || true

stop:
	docker stop wp || true

build: stop
	docker build -t ebreton/wp .

wp: mariadb build
	docker run --rm --name wp -d -p 8080:80 -e DATABASE_URL=mysql://root:secret@maria/wp ebreton/wp:latest

init: wp
	docker exec wp init.sh