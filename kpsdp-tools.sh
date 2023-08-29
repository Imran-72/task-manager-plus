#!/bin/bash

FAST_BUILD=0
BUILD_TYPE=0
STATUS=0
INDEX=0
SCRIPT_VERSION=2

if [ -r "./conf/deploy.conf" ]
then
	source ./conf/deploy.conf  
else
	printf "Ошибка! Отсутствует файл конфигурации!\n"
        exit 1
fi

if [[ $STRICTMODE -eq 1 ]]; then
    set -euo pipefail
    IFS=$'\n\t'
else
    set -u
fi

log_filename_time=$(date +%Y-%m-%d-%H-%M)
log_filename=$SCRIPT_DIR"/logs/kpsdp-tools-$log_filename_time.log"
#log_masscopy_filename=$SCRIPT_DIR"/logs/masscopy-$log_filename_time.log"

if [ -r "./tomcat_library_visual.sh" ]
then
	source ./tomcat_library_visual.sh  
else
	printf "Ошибка! Отсутствует файл библиотеки работы с Tomcat!\n"
        exit 1
fi

if [ -r "./git_library.sh" ]
then
	source ./git_library.sh  
else
	printf "Ошибка! Отсутствует файл библиотеки работы с git!\n"
        exit 1
fi

if [ -r "./logging_settings.sh" ]
then
    source ./logging_settings.sh
fi

if [ -r "./build_library_visual.sh" ]
then
	source ./build_library_visual.sh  
else
	printf "Ошибка! Отсутствует файл библиотеки функций сборки!\n"
        exit 1
fi

if [ -r "./db_library.sh" ]
then
	source ./db_library.sh  
else
	printf "Ошибка! Отсутствует файл библиотеки функций работы с БД!\n"
        exit 1
fi

if [ -r "./service_library_visual.sh" ]
then
	source ./service_library_visual.sh  
else
	printf "Ошибка! Отсутствует файл библиотеки функций работы с сервисами!\n"
        exit 1
fi

choose_delete_script_logs()
{
    local tempfile=/tmp/choosedsel$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM
    dialog  --title "Внимание!" \
            --backtitle "Attention" \
            --clear \
            --nocancel \
            --menu "Удалить log-файлы скрипта?" 20 61 5 \
            1 "Да" \
            2 "Нет" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        
    
    case $choice in
        1) 
            delete_script_logs
        ;;
    esac

    clear
}


if ! [ -d "$gitpath" ]; then
    message_box "Каталог git не найден!"
    exit 1
fi


if [[ $ASKFORSCRIPTLOGDELETE -eq 1 ]]; then
    choose_delete_script_logs
fi

if [[ $AUTODELETESCRIPTLOGS -eq 1 ]]; then
    delete_script_logs
fi

if [[ $ASKFORUPDATESCRIPT -eq 1 ]]; then
    check_script_version
fi
    
#trap "error_box" 0 1 2 5 15

if [ ! -f "$log_filename" ] 
then
	touch "$log_filename"
fi

LOGFILENAME=""
DUMPS_PATH=$gitdumpspath

if [ -r "cron/error.txt" ]
then
    message_box "Произошла ошибка при автоапдейте схемы БД! См. логи в logs/cron"
    rm -f "cron/error.txt"
fi

script_services_menu()
{
for((;;))
do
    local tempfile=/tmp/scriptservicemenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --title "Меню работы со скриптом" --clear \
            --no-cancel \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1 "Просмотр текущего log-файла" "Просмотр содержимого log-файла kpsdp-tools" \
            2 "Удаление всех log-файлов кроме созданных за последние 10 минут" "Удаление старых log-файлов" \
            3 "Копирование новой версии" "Копирование последней версии tomcat-tools из локального репозитория и перезапуск скрипта" \
            4 "Редактирование конфигурации" "Редактирование конфигурационного файла tomcat-tools" \
            5 "Обновить генератор меню" "Обновить генератор меню" \
            X "Назад" "Возврат в главное меню" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            show_script_log
        ;;
        2)
            delete_script_logs
        ;;
        3)
            rsync -crq --update --delete "$gitpath"/tomcat-tools/* "$HOME"/tomcat-tools &>> "$log_filename"
            chmod 755 "$HOME"/tomcat-tools/kpsdp-tools.sh
            local ScriptLoc
            ScriptLoc=$(readlink -f "$0")
            exec "$ScriptLoc"
        ;;
        4)
            edit_config_file
        ;;
        5)
            rsync -crq --update --delete "$gitpath"/tomcat-tools/generator/* "$HOME"/tomcat-tools/generator &>> "$log_filename"
        ;;
        X)
            return
        ;;
    esac
done
}

services_menu()
{
for((;;))
do
    local tempfile=/tmp/servicemenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --title "Меню работы с сервисами" --clear \
            --no-cancel \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1  "Вернуть статус сервисов" "Проверить статус сервисов \"запущен/не запущен\"" \
            2  "Перезапустить сервис" "Перезапустить сервис" \
            X  "Назад" "Вернуться в главное меню" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            service_status
        ;;
        2)
            restart_service
        ;;
        X)
            return
        ;;
    esac
done
}

git_menu()
{
for((;;))
do
    local tempfile=/tmp/gitmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --title "Меню работы с системой контроля версий" --clear \
            --no-cancel \
            --item-help \
            --menu "Список команд" 20 120 10 \
            1  "Обновить исходный код" "Обновить исходный код" \
            2  "Переключить ветку вручную" "Переключить ветку вручную" \
            3  "Переключить локальную ветку" "Переключить локальную ветку" \
            4  "Забрать удаленную ветку" "Забрать удаленную ветку" \
            5  "Вернуться в develop" "Переключиться на ветку develop" \
            6  "Имя текушей ветки" "Выводится имя текущей ветки" \
            7  "Обновить репозиторий kpsdp-tools" "Обновление репозитория kpsdp-tools" \
            8  "Удаление локальных веток" "Удаление локальных веток" \
            9  "Статус git" "Выводится статус git" \
            X  "Назад" "Вернуться в главное меню" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        
    local retVal=0

    case $choice in
        1)
            clear
            git_pull
            ;;
        2)
            git_change_branch
        ;;
        3)
            git_change_local_branch
        ;;
        4)
            git_change_remote_branch
        ;;
        5)
            git_clean
            cd "$gitpath"
            information_box "Переключение на ветку develop началось"
            git checkout develop &>> "$log_filename"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка переключения на ветку develop"
                error_dialog "Ошибка переключения на ветку develop, ${BASH_SOURCE[0]}, $LINENO"
                cd "$SCRIPT_DIR"
                continue
            fi
            information_box "Пеpеключение на ветку develop закончилась"
            cd "$SCRIPT_DIR"
        ;;
        6)
            clear
            git_branch_name
            ;;
        7)
            clear
            cd "$gitkpsdptoolspath"
            information_box "Началось обновление kpsdp-tools develop"
            git checkout develop &>> "$log_filename"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка переключения на ветку develop"
                error_dialog "Ошибка переключения на ветку kpsdp-tools develop, ${BASH_SOURCE[0]}, $LINENO"
                cd "$SCRIPT_DIR"
                continue
            fi
            git pull &>> "$log_filename"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка скачивания изменений"
                error_dialog "Ошибка скачивания изменений kpsdp-tools develop, ${BASH_SOURCE[0]}, $LINENO"
                cd "$SCRIPT_DIR"
                continue
            fi            
            information_box "Oбновление kpsdp-tools develop закончилась"
            cd "$SCRIPT_DIR"
        ;;
        8)
            git_delete_local_branches
        ;;
        9)
            get_git_status
        ;;
        X)
            return
        ;;
    esac
done
}

interactive_build_menu()
{
for((;;))
do
    local tempfile=/tmp/deploymenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --title "Меню сборки КП СДП" --clear \
            --no-cancel \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1  "Cобрать и установить ВСЕ с перезапуском tomcat" "Обновление сервисов, фронта и базы данных" \
            2  "Cобрать и установить сервисы и фронт с перезапуском tomcat" "Обновление сервисов и фронта" \
            3  "Cобрать и установить сервисы с перезапуском tomcat" "Обновление сервисов" \
            4  "Cобрать и установить фронт" "Обновление фронта" \
            5  "Cобрать и установить фронт без копирования" "Обновление фронта" \
            6  "Cобрать и установить сервисы и обновить БД с перезапуском tomcat" "Обновление сервисов и базы данных" \
            X  "Назад" "Вернуться в главное меню сборки" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        
    
    case $choice in
        1)
            stop_tomcat
            ask_for_build_type
            build_deploy
            update_context_files
            update_services_metadata
            tempfile=/tmp/builddb$$
            trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM
            dialog  --title "Внимание!" \
                    --backtitle "Attention" \
                    --clear \
                    --nocancel \
                    --menu "Обновлять базы данных?" 20 61 5 \
                    1 "Да" \
                    2 "Нет" 2> $tempfile

            choice=$(cat $tempfile)
            rm -f $tempfile        
            
            case $choice in
                1) 
                    restore_all_db
                ;;
            esac
            change_debug_level
            start_tomcat
        ;;
        2)
            stop_tomcat
            ask_for_build_type
            build_deploy
            update_context_files
            update_services_metadata
            change_debug_level
            start_tomcat
        ;;
        3)
            stop_tomcat
            ask_for_build_type
            build_services
            update_context_files
            update_services_metadata
            change_debug_level
            start_tomcat
        ;;
        4)
            build_front
        ;;
        5)
            build_front_no_copy
        ;;
        6)
            stop_tomcat
            ask_for_build_type
            build_services
            update_context_files
            update_services_metadata
            restore_all_db
            change_debug_level
            start_tomcat
        ;;
        X)
            return
        ;;
    esac
done
}

auto_build_menu()
{
for((;;))
do
    local tempfile=/tmp/deploymenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --title "Меню сборки КП СДП" --clear \
            --no-cancel \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1  "Cобрать и установить ВСЕ с перезапуском tomcat" "Обновление сервисов, фронта и базы данных" \
            2  "Cобрать и установить сервисы и фронт с перезапуском tomcat" "Обновление сервисов и фронта" \
            3  "Cобрать и установить сервисы с перезапуском tomcat" "Обновление сервисов" \
            4  "Cобрать и установить фронт" "Обновление фронта" \
            5  "Cобрать и установить фронт без копирования" "Обновление фронта" \
            6  "Cобрать и установить сервисы и обновить БД с перезапуском tomcat" "Обновление сервисов и базы данных" \
            X  "Назад" "Вернуться в главное меню сборки" 2> $tempfile

    local retVal=$?
    local current_date
    current_date=$(date +%d-%m-%Y)
    local current_time
    current_time=$(date +%H:%M:%S)
    local start_time
    start_time=$(date +%s)

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        
    
    case $choice in
        1)
#            ask_for_maven_update
            stop_tomcat_unattended
            git_pull_unattended
            build_services_and_front_unattended
            update_context_files_unattended
            update_services_metadata_unattended
            restore_all_db_unattended
            start_tomcat_unattended
            reindex_search_system
        ;;
        2)
#           ask_for_maven_update
            stop_tomcat_unattended
            git_pull_unattended
            build_services_and_front_unattended
            update_context_files_unattended
            update_services_metadata_unattended
            start_tomcat_unattended
        ;;
        3)
#            ask_for_maven_update
            stop_tomcat_unattended
            git_pull_unattended
            clear
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            start_time=$(date +%s)
            information_box "Сборка началась $current_date $current_time"
            copy_config
            cd "$jrfontspath"
            source ./install_fonts.sh &>> "$log_filename"
            cd "$SCRIPT_DIR"
            clear
            build_service_bundle_unattended
            update_context_files_unattended
            clear
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            echoWithDate "Сборка окончилась $current_date $current_time"
            echoWithDate "Длительность: $(($(date +%s)-start_time)) секунд" 
            information_box "Сборка окончилась $current_date $current_time\nДлительность: $(($(date +%s)-start_time)) секунд"
            start_tomcat_unattended
        ;;
        4)
            git_pull_unattended
            clear
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            start_time=$(date +%s)
            information_box "Идет сборка фронта..."
            build_front_atom_unattended
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            echoWithDate "Сборка окончилась $current_date $current_time" 
            echoWithDate "Длительность: $(($(date +%s)-start_time)) секунд" 
            information_box "Сборка окончилась $current_date $current_time\nДлительность: $(($(date +%s)-start_time)) секунд"
        ;;
        5)
            git_pull_unattended
            clear
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            start_time=$(date +%s)
            information_box "Идет сборка фронта..."
            build_front_atom_no_copy_unattended
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            echoWithDate "Сборка окончилась $current_date $current_time" 
            echoWithDate "Длительность: $(($(date +%s)-start_time)) секунд" 
            information_box "Сборка окончилась $current_date $current_time\nДлительность: $(($(date +%s)-start_time)) секунд"
        ;;
        6)
#            ask_for_maven_update
            stop_tomcat_unattended
            git_pull_unattended
            clear
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            start_time=$(date +%s)
            information_box "Сборка началась $current_date $current_time"
            copy_config
            cd "$jrfontspath"
            source ./install_fonts.sh &>> "$log_filename"
            cd "$SCRIPT_DIR"
            clear
            build_service_bundle_unattended
            update_context_files_unattended
            update_services_metadata_unattended
            restore_all_db_unattended
            clear
            current_date=$(date +%d-%m-%Y)
            current_time=$(date +%H:%M:%S)
            echoWithDate "Сборка окончилась $current_date $current_time"
            echoWithDate "Длительность: $(($(date +%s)-start_time)) секунд" 
            information_box "Сборка окончилась $current_date $current_time\nДлительность: $(($(date +%s)-start_time)) секунд"
            information_box "Началась переиндексация БД системы поиска..."
            start_tomcat_unattended
            reindex_search_system
        ;;
        X)
            return
        ;;
    esac
done
}

choose_build()
{
    local tempfile=/tmp/choosebuild$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM
    dialog  --title "Внимание!" \
            --backtitle "Attention" \
            --clear \
            --item-help \
            --nocancel \
            --menu "Выберите вaриант сборки сервисов" 20 61 5 \
            1 "Стандартная сборка" "Вариант с полной пересборкой всех сервисов" \
            2 "Быстрая сборка" "Вариант с пересборкой только измененных сервисов" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    
    case $choice in
        1)
            FAST_BUILD=0
        ;;
        2)
            FAST_BUILD=1
        ;;
    esac
    return
}

deploy_menu()
{
for((;;))
do
    local tempfile=/tmp/deploymenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --title "Меню сборки КП СДП" --clear \
            --no-cancel \
            --item-help \
            --menu "Список команд " 32 120 10 \
            1  "Команды интерактивной сборки компонентов КПСДП" "Команды интерактивной сборки компонентов КПСДП" \
            2  "Команды автоматической сборки компонентов КПСДП" "Команды автоматической сборки компонентов КПСДП" \
            3  "Копировать конфигурационные файлы" "Копирование конфигурационных файлов tomcat в каталог tomcat8/config" \
            4  "Забрать актуальную версию проекта из удаленного репозитория" "Забрать исходные коды проекта из удаленного репозитория" \
            5  "Обновить БД с помощью liquibase" "Обновить структуру базы данных" \
            6  "Собрать отдельный сервис вручную" "Собрать заданный сервис" \
            7  "Установить шрифты для JR" "Установить шрифты для JR" \
            8  "Обновить Платформу" "Обновление модулей Диасофт" \
            9  "Обновить конфигурацию tomcat" "Обновление файлов конфигурации tomcat8/conf" \
            A "Обновить репозиторий maven" "Обновление библиотек репозитория maven" \
            B "Обновить метаданные сервисов" "Обновление метаданных сервисов" \
            C "Обновить библиотеки node.js" "Обновление библиотек node.js" \
            D "Обновить системные библиотеки платформы" "Обновление библиотек платформы" \
            E "Скопировать файл лицензии платформы" "Скопировать файл лицензии платформы" \
            F "Поменять версию фронта" "Поменять версию фронта" \
            G "Изменить уровень логирования" "Уровни DEBUG, INFO, ERROR" \
            H "Обновить скрипт dUpdate" "Обновить скрипт dUpdate" \
            I "Обновить БД с помощью dbUpdate" "Обновить структуру базы данных" \
            J "Обновить внешние библиотеки платформы" "Обновить shared-lib" \
            K "Обновить контекстные файлы платформы и проекта" "Обновить tomcat8/conf/Catalina/localhost" \
            L "Копирование собранных сервисов в kpsdp" "Копирование собранных сервисов в kpsdp" \
            M "Собрать отдельный сервис из списка" "Собрать заданный сервис" \
            N "Собрать выбранные сервисы" "Собрать выбранные из списка сервисы " \
            X  "Назад" "Вернуться в главное меню" 2> $tempfile

    local retVal=$?

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        
    
    case $choice in
        1)
            ask_for_maven_update
            choose_build
            interactive_build_menu
        ;;
        2)
            ask_for_maven_update
            auto_build_menu
        ;;
        3)
            clear
            copy_config
        ;;
        4)
            clear
            git_pull
        ;;
        5)
            update_database_scheme
        ;;
        6)
            clear
            build_one_service_by_hand
        ;;
        7)
            clear
            information_box "Началась установка шрифтов..."
            cd "$jrfontspath"
            source ./install.sh &>> "$log_filename"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка установки шрифтов"
                error_dialog "Ошибка установки шрифтов, ${BASH_SOURCE[0]}, $LINENO"
                cd "$SCRIPT_DIR"
                continue
            fi
            cd "$SCRIPT_DIR"
            information_box "Установка шрифтов закончена"
        ;;
        8)
            clear
            information_box "Началось обновление платформы..."
            update_platform
            information_box "Обновление платформы завершено"
        ;;
        9)
            clear
            information_box "Началось обновление конфигурации tomcat..."
            update_tomcat_config
            information_box "Обновление конфигурации tomcat завершено"
        ;;
        A)
            clear
            information_box "Началось обновление репозитория..."
            update_libraries
            information_box "Обновление репозитория завершено"
        ;;
        B)
            clear
            information_box "Началось обновление метаданных сервисов..."
            update_services_metadata
            information_box "Обновление метаданных сервисов завершено"
        ;;
        C)
            clear
            information_box "Началось обновление библиотек node.js..."
            cd "$gitfrontpath"
            rm -rf "${gitnodemodulespath:?}/"*
            npm install &>> "$log_filename"
            cd "$SCRIPT_DIR"
            information_box "Обновление библиотек node.js завершено"
        ;;
        D)
            clear
            information_box "Началась обновление системных библиотек платформы..."
            rm -rf "${sharedlibpath:?}/"*
            cp -f "$gitsharedlibpath"/* "$sharedlibpath"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка обновления системных библиотек платформы"
                error_dialog "Ошибка обновления системных библиотек платформы, ${BASH_SOURCE[0]}, $LINENO"
                cd "$SCRIPT_DIR"
                continue
            fi
            cd "$SCRIPT_DIR"
            information_box "Обновление системных библиотек платформы закончено"
        ;;
        E)
            clear
            copy_license_file
        ;;
        F)
            clear
            change_front_version
        ;;
        G)
            clear
            change_debug_level
        ;;
        H)
            clear
            update_db_script
        ;;
        I)
            clear
            update_db_with_script
        ;;
        J)
            clear
            update_shlib
        ;;
        K)
            clear
            update_context_files
        ;;
        L)
            clear
            stb_full
        ;;
        M)
            clear
            build_one_service_from_list
        ;;
        N)
            clear
            build_multiple_services_from_list
        ;;
        X)
            return
        ;;
    esac
done
}

elastic_menu()
{
for((;;))
do
    local tempfile=/tmp/elasticmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --no-cancel \
            --title "Меню работы с поисковиком Elastic" --clear \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1 "Обновить систему поиска Elastic" "Обновление системы поиска Elastic" \
            2 "Переиндексировать БД системы поиска Elastic" "Переиндексация системы поиска" \
            X  "Назад" "Вернуться в главное меню" 2> $tempfile

    local retVal=$?

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            clear
            ok_cancel_dialog "Эта команда устарела"
            retVal=$?
            if [ $retVal -ne 1 ]; then
                return
            fi
            information_box "Началось обновление системы поиска..."
            update_elastic_search_system
            tempfile1=/tmp/builddb$$
            trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM
            dialog  --title "Внимание!" \
                    --backtitle "Attention" \
                    --clear \
                    --nocancel \
                    --menu "Переиндексировать БД поиска?" 20 61 5 \
                    1 "Да" \
                    2 "Нет" 2> $tempfile1

            choice=$(cat $tempfile1)
            rm -f $tempfile1        
            
            case $choice in
                1) 
                    reindex_elastic_search_system
                ;;
            esac
            information_box "Обновление системы поиска завершено"
        ;;
        2)
            clear
            reindex_elastic_search_system
        ;;
        X)
            return
        ;;
    esac
done
}

stb_menu()
{
for((;;))
do
    local tempfile=/tmp/stbmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --no-cancel \
            --title "Меню работы с сервером STB" --clear \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1 "Запустить webclient + kpsdp add-ons" "Запускаются сервисы платформы и сервисы для дополнений к вебклиенту" \
            2 "Запустить webclient" "Запускаются сервисы платформы" \
            3 "Регистрация сервиса" "Регистрация или перерегистрация сервиса" \
            4 "Очистка каталога webapps" "Очистка каталога webapps" \
            5 "Запустить полную версию проекта" "Запускаются сервисы платформы и сервисы КПСДП" \
            6 "Очистить логи автоапдейта схемы" "Очистить логи автоапдейта схемы" \
            X  "Назад" "Вернуться в главное меню" 2> $tempfile

    local retVal=$?

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            clear
            stb_webclient_and_addons
            start_tomcat
        ;;
        2)
            clear
            stb_webclient
            start_tomcat
        ;;
        3)
            clear
            stb_service_registration
        ;;
        4)
            clear
            stb_webapps_clean
        ;;
        5)
            clear
            stb_full
            start_tomcat
        ;;
        6)
            clear
            delete_cron_logs
        ;;
        X)
            return
        ;;
    esac
done
}

search_menu()
{
for((;;))
do
    local tempfile=/tmp/stbmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --no-cancel \
            --title "Меню работы с системой поиска" --clear \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1 "Установить kpsdp-search" "Установить поисковую систему" \
            2 "Запустить kpsdp-search" "Запустить сервис поиска" \
            3 "Остановить kpsdp-search" "Остановить сервис поиска" \
            4 "Собрать сервис kpsdp-search и конфигурацию с рестартом поиска" "Установить сервис kpsdp-search" \
            5 "Собрать и установить сервис kpsdp-search с рестартом поиска" "Установить сервис kpsdp-search" \
            6 "Собрать и установить сервис kpsdp-search без рестарта поиска" "Установить сервис kpsdp-search" \
            7 "Обновить конфигурацию с рестартом поиска" "Обновить конфигурацию поиска" \
            8 "Обновить конфигурацию без рестарта поиска" "Обновить конфигурацию поиска" \
            9 "Обновить настройки логирования поиска" "Обновить настройки логирования поиска" \
            A "Посмотреть статус системы поиска" "Статус поиска" \
            B "Переиндексация системы поиска 'на лету'" "Переиндексация" \
            X "Назад" "Вернуться в главное меню" 2> $tempfile

    local retVal=$?

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            clear
            message_box "Для установки поиска нажмите 'Ok'.\nНа запрос ввода пароля ввести пароль пользователя dev"
            cd "$gitkpsdpsearchdir"/setup || return
            bash ./install.sh
            cd "$SCRIPT_DIR" || return
            build_kpsdp_service
            message_box "Установка kpsdp-search закончена"
        ;;
        2)
            clear
            start_kpsdp_search
        ;;
        3)
            clear
            stop_kpsdp_search
        ;;
        4)
            clear
            stop_kpsdp_search_unattended
            build_kpsdp_service
            update_kpsdp_search_config
            start_kpsdp_search_unattended
            message_box "Сборка сервиса kpsdp-search закончена"
        ;;
        5)
            clear
            stop_kpsdp_search_unattended
            build_kpsdp_service
            start_kpsdp_search_unattended
            message_box "Сборка сервиса kpsdp-search закончена"
        ;;
        6)
            clear
            build_kpsdp_service
        ;;
        7)
            clear
            stop_kpsdp_search_unattended
            update_kpsdp_search_config
            start_kpsdp_search_unattended
            message_box "Копирование конфигурации закончено"
        ;;
        8)
            clear
            update_kpsdp_search_config
        ;;
        9)
            clear
            update_kpsdp_search_log4j
        ;;
        A)
            clear
            show_kpsdp_search_status
        ;;
        B)
            clear
            information_box "Переиндексация начата..."
            cd "$kpsdpsearchbindir" || { echoWithDate "Отсутствует каталог $kpsdpsearchbindir"; return; }
            ./indexer --all --rotate &>> "$log_filename"
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка переиндексации"
                error_dialog "Ошибка переиндексации, ${BASH_SOURCE[0]}, $LINENO"
                cd "$SCRIPT_DIR" || { echoWithDate "Отсутствует каталог $SCRIPT_DIR"; exit 1; }
                return
            fi
            cd "$SCRIPT_DIR"
            message_box "Переиндексация закончена"
        ;;
        X)
            return
        ;;
    esac
done
}

tomcat_menu()
{
for((;;))
do    
    local tempfile=/tmp/tomcatmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --no-cancel \
            --title "Меню работы с tomcat" --clear \
            --item-help \
            --menu "Список команд " 23 120 10 \
            1 "Статус tomcat"  "Получить статус tomcat" \
            2 "Запустить tomcat" "" \
            3 "Остановить tomcat" "" \
            4 "Принудительная остановка tomcat" "" \
            5 "Рестартовать tomcat" "" \
            6 "Обнулить log-файлы" "Удалить содержимое log-файлов tomcat" \
            7 "Динамический просмотр log-файла" "Просмотр изменений заданного log-файла в режиме реального времени" \
            8 "Просмотр log-файла" "Просмотр текущего содержимого выбанного log-файла" \
            9 "Запустить tomcat (Alexey Zhikharev edition)" "" \
            A "Рестартовать tomcat (Alexey Zhikharev edition)" "" \
            B "Удалить log-файлы" "Удалить log-файлы tomcat" \
            C "Генератор log4j.properties" "" \
            D "Создать архив логов томкета" "" \
            E "Создать архив логов ТТ" "" \
            X "Назад" "Вернуться в предыдущее меню" 2> $tempfile

    local retVal=$?

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            tomcat_status;
        ;;
        2)
            change_debug_level
            start_tomcat
        ;;
        3)
            information_box "Tomcat останавливается..."
#            shutdown_tomcat
            stop_tomcat
        ;;
        4)
            stop_tomcat
        ;;
        5)
#            shutdown_tomcat
            stop_tomcat
            change_debug_level
            start_tomcat
        ;;
        6)
            clear_logs
        ;;
        7)
            watch_catalina
        ;;
        8)
            edit_log_file
        ;;
        9)
            reindex_search_system
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка переиндексация БД cистемы поиска"
                error_dialog "Ошибка переиндексация БД cистемы поиска, ${BASH_SOURCE[0]}, $LINENO"
                continue
            fi
            start_tomcat_unattended
        ;;
        A)
#            shutdown_tomcat_unattended
            stop_tomcat_unattended
            reindex_search_system
            retVal=$?
            if [ $retVal -ne 0 ]; then
                echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка переиндексация БД cистемы поиска"
                error_dialog "Ошибка переиндексация БД cистемы поиска, ${BASH_SOURCE[0]}, $LINENO"
                continue
            fi
            start_tomcat_unattended
        ;;
        B)
            delete_tomcat_logs
        ;;
        C)
            make_log4j_properties
        ;;
        D)
            make_tomcat_logs
        ;;
        E)
            make_tt_logs
        ;;
        X)
            return
        ;;
    esac
done
}

main()
{
for((;;))
do
    local tempfile=/tmp/mainmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите блок команд..." \
            --no-cancel \
            --item-help \
            --title "Основное меню" --clear \
            --menu "Список блоков команд " 20 120 10 \
            1 "Команды сборки и установки КП СДП" "Команды сборки компонентов" \
            2 "Команды для работы с tomcat" "Команды работы с tomcat" \
            3 "Команды работы с БД" "Команды работы с базой данных" \
            4 "Команды работы с сервисами" "Работа с сервисами tomcat" \
            5 "Команды для обслуживания скрипта" "Обслуживание скрипта tomcat-tools" \
            6 "Команды работы с git" "Команды работы с git" \
            7 "Команды работы с поиском kpsdp-search" "Команды работы с поиском kpsdp-search" \
            8 "Команды работы с поиском Elastic" "Команды работы с поиском Elastic" \
            9 "Команды для работы с сервером генерирования исходных кодов (STB)" "Команды,специфичные для STB" \
            A "Обновить конфигурационный файл ТТ" "Обновляется конфигурационный файл ТТ" \
            X "Возврат в Стартовое меню" "Выход" 2> $tempfile


    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            deploy_menu
        ;;
        3)
            db_menu
        ;;
        2)
            tomcat_menu
        ;;
        4)
            services_menu
        ;;
        5)
            script_services_menu
        ;;
        6)
            git_menu
        ;;
        7)
            search_menu
        ;;
        8)
            elastic_menu
        ;;
        9)
            stb_menu
        ;;
        A)
            ask_for_script_configuration_update
        ;;
        X)
            clear
            return
        ;;
    esac
done
}

source ./local-menu/quick_menu.sh


check_for_updates()
{
    git_clean
    
    information_box "Проверяем наличие обновлений..."
    echoWithDate "Проверяем наличие обновлений..."
    
    git_check_remote_branch_name
    ret=$?
    if [ $ret -ne 0 ]; then
        echoWithDate "Ветка не найдена в удаленном репозитории"
        message_box "Ветка не найдена в удаленном репозитории"
        cd "$SCRIPT_DIR"
        return
    fi
    
    cd "$gitpath"
    
    local isUpdate
    isUpdate=$(git fetch 2>&1)
    
    local ret=$?
    echoWithDate "git fetch retval = $ret"
    if [ $ret -ne 0 ]; then
        echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка подключения к репозиторию"
        error_dialog "Ошибка подключения к репозиторию, ${BASH_SOURCE[0]}, $LINENO"
        cd "$SCRIPT_DIR"
        return
    fi
    
    currentBranch=$(get_current_branch_name)

    echoWithDate "currentBranch = $currentBranch"
    
    isUpdate=$(git log "$currentBranch"..origin/"$currentBranch")
    echoWithDate "isUpdate = $isUpdate"
    ret=$?
    if [ -z "$isUpdate" ] && [ $ret -eq 0 ]
    then
        echoWithDate "Обновления не найдены"
        message_box "Обновления не найдены"
        cd "$SCRIPT_DIR"
        return
    elif [ $ret -ne 0 ]
    then
        echoWithDate "[${BASH_SOURCE[0]}, $LINENO] Ошибка подключения к репозиторию"
        error_dialog "Ошибка подключения к репозиторию, ${BASH_SOURCE[0]}, $LINENO"
    fi

    
    cd "$SCRIPT_DIR"
    
    local tempfile=/tmp/tomcatmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --no-cancel \
            --title "Обнаружены обновления в проекте" --clear \
            --item-help \
            --menu "Обновлять исходные коды?" 20 120 10 \
            1 "Да" "Обновить" \
            2 "Нет" "Не обновлять" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            clear
            git_pull
            message_box "Обновления получены, не забудьте пересобрать проект"
            cd "$SCRIPT_DIR"
            return
        ;;
        2)
            cd "$SCRIPT_DIR"
            return
        ;;
    esac
    cd "$SCRIPT_DIR"
}

start_menu()
{
for((;;))
do    
    local tempfile=/tmp/startmenu$$
    trap 'rm -f "$tempfile"' 0 SIGHUP SIGINT SIGTRAP SIGTERM

    dialog  --backtitle "Выберите команду..." \
            --no-cancel \
            --title "Стартовое меню" --clear \
            --item-help \
            --menu "Список команд " 20 120 10 \
            1 "Основное меню" "Переход в основное меню" \
            2 "Быстрое меню" "Переход в быстрое меню" \
            X "Выход из программы" "Выход" 2> $tempfile

    local choice
    choice=$(cat $tempfile)
    rm -f $tempfile        

    case $choice in
        1)
            if [[ $CHECKFORUPDATES -eq 1 ]]; then
                check_for_updates
            fi
            main
        ;;
        2)
            quick_menu
        ;;
        X)
            exit
        ;;
    esac
done
}

start_menu
