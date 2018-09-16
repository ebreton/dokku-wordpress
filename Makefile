DOKKU_HOST:=breton.ch
DOKKU_LETSENCRYPT_EMAIL:=manu@ibimus.com
DOKKU_MARIADB_SERVICE:=mysql

SITE_TITLE:=Dokku WP
WP_USER:=admin
WP_PASSWORD:=admin
WP_EMAIL:=email@example.com


LOCAL_BACKUP_PATH:=~/var/dokku_backup

###
# ONE OFF

init-host:	
	# set email to use for let's encrypt globally
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
	ssh -t dokku@${DOKKU_HOST} config:set --global DOKKU_LETSENCRYPT_EMAIL=${DOKKU_LETSENCRYPT_EMAIL}
	# setup MariaDB
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-mariadb.git
	ssh -t dokku@${DOKKU_HOST} mariadb:create ${DOKKU_MARIADB_SERVICE} || true
	# pull initial docker image for Wordpress
	ssh -t ${DOKKU_HOST} docker pull wordpress:4.9-php5.6-apache


###
# CREATE & DESTROY

create: validate-app
	# create an app and set environment variable+port before 1st deployment
	ssh -t dokku@${DOKKU_HOST} apps:create ${NAME}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} SITE_URL=https://${NAME}.${DOKKU_HOST}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} SITE_TITLE=\"${SITE_TITLE}\"
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WP_USER=\"${WP_USER}\"
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WP_PASSWORD=\"${WP_PASSWORD}\"
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} WP_EMAIL=${WP_EMAIL}
	# link with DB
	ssh -t dokku@${DOKKU_HOST} mariadb:link ${DOKKU_MARIADB_SERVICE} ${NAME}
	# add remote and push app to trigger deployment on host
	git remote add ${NAME} dokku@${DOKKU_HOST}:${NAME}
	git push ${NAME} master
	# switch to HTTPs
	ssh -t dokku@${DOKKU_HOST} letsencrypt ${NAME}
	# mount volume for images
	ssh -t dokku@${DOKKU_HOST} storage:mount ${NAME} /var/lib/dokku/data/storage/${NAME}:/var/www/html
	ssh -t dokku@${DOKKU_HOST} ps:restart ${NAME}
	# initialize WP
	ssh -t dokku@${DOKKU_HOST} run ${NAME} init.sh

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

config: validate-app
	ssh -t dokku@${DOKKU_HOST} config ${NAME}


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
# LOCAL TESTING

mariadb:
	docker run --rm --name maria -e MYSQL_ROOT_PASSWORD=secret -d mariadb || true

stop:
	docker stop wp || true

reset: stop
	docker exec maria mysql -u root --password=secret -e "DROP DATABASE IF EXISTS wp;"

build: stop
	docker build -t ebreton/wp .

wp: mariadb build
	docker run --rm --link maria --name wp -d -p 8080:80 \
		-e DATABASE_URL=mysql://root:secret@maria/wp \
		-e SITE_URL=localhost:8080 \
		-e SITE_TITLE='Dokku WP' \
		-e WP_USER=admin \
		-e WP_PASSWORD=admin \
		-e WP_EMAIL=wp@example.com \
		ebreton/wp:latest

init: wp
	docker exec wp init.sh

is-installed:
	docker exec wp sudo -u www-data wp core is-installed

exec:
	docker exec -it wp bash