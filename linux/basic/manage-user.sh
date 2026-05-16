#!/bin/bash

# Использование:
#   create_user username userpassword [s]
#       s - если требуется добавить пользователя в группу sudo
function create_user() {
    local USER_NAME=${1}
    if [ -z "${USER_NAME}" ]; then
        echo "Не передано имя пользователя"
        return 1
    fi
    
    local USER_PASSWORD=${2}
    if [ -z "${USER_PASSWORD}" ]; then
        echo "Не передан пароль"
        return 1
    fi

    if getent passwd "${USER_NAME}" > /dev/null; then
        echo "Пользователь ${USER_NAME} уже существует"
    else
        echo "Создание пользователя ${USER_NAME}"

        sudo adduser --disabled-password --gecos "" ${USER_NAME}

        if [ ${?} -eq 0 ]; then
            echo "Пользователь ${USER_NAME} создан"

            echo "Установка пароля для пользователя ${USER_NAME}"

            echo "${USER_NAME}:${USER_PASSWORD}" | sudo chpasswd

            if [ ${?} -eq 0 ]; then
                echo "Пароль для пользователя ${USER_NAME} установлен"
            else
                echo "Не удалось установить пароль для пользователя ${USER_NAME}"
                return 1
            fi
        fi
    fi

    local SUDOER=${3}
    if [[ ${SUDOER} == "s" ]]; then
        if id -nG "${USER_NAME}" | grep -qw "sudo"; then
            echo "Пользователь ${USER_NAME} уже состоит в группе sudo"
        else
            echo "Добавление пользователя ${USER_NAME} в группу sudo"
            
            sudo usermod -aG sudo ${USER_NAME}

            if [ ${?} -eq 0 ]; then
                echo "Пользователь ${USER_NAME} добавлен в группу sudo"
            else
                echo "Не удалось добавить пользователя ${USER_NAME} в группу sudo"
                return 1
            fi
        fi
    fi
}

# Использование:
#   delete_user username
function delete_user() {
    local USER_NAME=${1}
    if [ -z "${USER_NAME}" ]; then
        echo "Не передано имя пользователя"
        return 1
    fi

    if getent passwd "${USER_NAME}" > /dev/null; then
        echo "Удаление пользователя ${USER_NAME}"

        sudo deluser --remove-home ${USER_NAME}

        if [ ${?} -eq 0 ]; then
            echo "Пользователь ${USER_NAME} удален"
        else
            echo "Не удалось удалить пользователя ${USER_NAME}"
            return 1
        fi
    else
        echo "Пользователь ${USER_NAME} не существует"
        return 1
    fi
}