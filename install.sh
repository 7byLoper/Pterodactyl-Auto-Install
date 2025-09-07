#!/bin/bash

# Конфигурация
THEME_URLS=(
    "https://github.com/7byLoper/Pterodactyl-Auto-Install/raw/main/stellar.zip"
    "https://github.com/7byLoper/Pterodactyl-Auto-Install/raw/main/billing.zip"
    "https://github.com/7byLoper/Pterodactyl-Auto-Install/raw/main/enigma.zip"
)

REPAIR_SCRIPT_URL="https://raw.githubusercontent.com/7byLoper/Pterodactyl-Auto-Install/main/repair.sh"
PANEL_INSTALLER_URL="https://pterodactyl-installer.se"
NODEJS_SETUP_URL="https://deb.nodesource.com/setup_16.x"

# Цвета
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Пути
TEMP_DIR="/root/pterodactyl"
PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/root/pterodactyl_backup_$(date +%Y%m%d_%H%M%S)"

# Функции для вывода сообщений
print_header() {
    echo -e "\n${BLUE}[+] =============================================== [+]${NC}"
    echo -e "${BLUE}[+] $1${NC}"
    echo -e "${BLUE}[+] =============================================== [+]${NC}\n"
}

print_success() {
    echo -e "\n${GREEN}[+] =============================================== [+]${NC}"
    echo -e "${GREEN}[+] $1${NC}"
    echo -e "${GREEN}[+] =============================================== [+]${NC}\n"
}

print_error() {
    echo -e "\n${RED}[+] =============================================== [+]${NC}"
    echo -e "${RED}[+] $1${NC}"
    echo -e "${RED}[+] =============================================== [+]${NC}\n"
}

print_warning() {
    echo -e "\n${YELLOW}[!] $1${NC}\n"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    local deps=("curl" "wget" "unzip" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Установка недостающих зависимостей: ${missing_deps[*]}"
        sudo apt update && sudo apt install -y "${missing_deps[@]}"
    fi
}

# Приветственное сообщение
display_welcome() {
    clear
    echo -e "${BLUE}[+] =============================================== [+]${NC}"
    echo -e "${BLUE}[+]                                                 [+]${NC}"
    echo -e "${BLUE}[+]          АВТОМАТИЧЕСКИЙ УСТАНОВЩИК ТЕМ           [+]${NC}"
    echo -e "${BLUE}[+]                                                 [+]${NC}"
    echo -e "${RED}[+] =============================================== [+]${NC}"
    echo -e "\nЭтот скрипт создан для облегчения установки темы Птеродактиль"
    echo -e ""
    sleep 2
}

# Установка jq
install_jq() {
    print_header "ОБНОВЛЕНИЕ И УСТАНОВКА JQ"
    
    if sudo apt update && sudo apt install -y jq; then
        print_success "JQ УСТАНОВЛЕН УСПЕШНО"
    else
        print_error "НЕ УДАЛОСЬ УСТАНОВИТЬ JQ"
        exit 1
    fi
    sleep 1
}

# Создание резервной копии
create_backup() {
    if [[ -d "$PANEL_DIR" ]]; then
        print_warning "Создание резервной копии текущей установки..."
        sudo cp -r "$PANEL_DIR" "$BACKUP_DIR" 2>/dev/null && \
        print_success "Резервная копия создана: $BACKUP_DIR"
    fi
}

# Восстановление из резервной копии
restore_backup() {
    if [[ -d "$BACKUP_DIR" ]]; then
        print_warning "Восстановление из резервной копии..."
        sudo rm -rf "$PANEL_DIR" && \
        sudo cp -r "$BACKUP_DIR" "$PANEL_DIR" && \
        print_success "Восстановление завершено"
    fi
}

# Очистка временных файлов
cleanup() {
    sudo rm -rf "$TEMP_DIR" 2>/dev/null
    sudo rm -f /root/*.zip 2>/dev/null
}

# Установка Node.js и зависимостей
setup_nodejs() {
    print_warning "Установка Node.js и зависимостей..."
    
    curl -sL "$NODEJS_SETUP_URL" | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm i -g yarn
    
    cd "$PANEL_DIR" || return 1
    yarn add react-feather
    php artisan migrate
    yarn build:production
    php artisan view:clear
    
    return 0
}

# Установка темы
install_theme() {
    local theme_names=("stellar" "billing" "enigma")
    
    while true; do
        print_header "ВЫБЕРИТЕ ТЕМУ"
        echo "ВЫБЕРИТЕ ТЕМУ, КОТОРУЮ ХОТИТЕ УСТАНОВИТЬ:"
        
        for i in "${!theme_names[@]}"; do
            echo "$((i+1)). ${theme_names[$i]}"
        done
        echo "x. Назад"
        
        read -rp "Введите параметры (1/2/3/x): " SELECT_THEME
        
        case "$SELECT_THEME" in
            1|2|3)
                local theme_index=$((SELECT_THEME-1))
                local theme_url="${THEME_URLS[$theme_index]}"
                local theme_file="/root/$(basename "$theme_url")"
                
                # Создание резервной копии
                create_backup
                
                # Очистка и загрузка темы
                cleanup
                print_header "УСТАНОВКА ТЕМЫ ${theme_names[$theme_index]}"
                
                if wget -q "$theme_url" -O "$theme_file" && \
                   sudo unzip -o "$theme_file" -d "$TEMP_DIR"; then
                    
                    # Копирование темы
                    sudo cp -rfT "$TEMP_DIR" "$PANEL_DIR"
                    
                    # Установка зависимостей
                    if setup_nodejs; then
                        # Дополнительные действия для billing темы
                        if [[ "$SELECT_THEME" -eq 2 ]]; then
                            php artisan billing:install stable
                        fi
                        
                        cleanup
                        print_success "ТЕМА ${theme_names[$theme_index]} УСТАНОВЛЕНА УСПЕШНО"
                        sleep 2
                        return 0
                    else
                        restore_backup
                        print_error "ОШИБКА УСТАНОВКИ ЗАВИСИМОСТЕЙ"
                    fi
                else
                    restore_backup
                    print_error "ОШИБКА ЗАГРУЗКИ ИЛИ РАСПАКОВКИ ТЕМЫ"
                fi
                ;;
            x)
                return 1
                ;;
            *)
                print_error "Неверный выбор, попробуйте еще раз"
                ;;
        esac
    done
}

# Удаление темы
uninstall_theme() {
    print_header "УДАЛЕНИЕ ТЕМЫ"
    
    if bash <(curl -s "$REPAIR_SCRIPT_URL"); then
        print_success "ТЕМА УДАЛЕНА УСПЕШНО"
    else
        print_error "ОШИБКА УДАЛЕНИЯ ТЕМЫ"
    fi
    sleep 2
}

# Создание узла
create_node() {
    print_header "СОЗДАНИЕ УЗЛА"
    
    read -rp "Введите название локации: " location_name
    read -rp "Введите описание местоположения: " location_description
    read -rp "Введите домен: " domain
    read -rp "Введите имя узла: " node_name
    read -rp "Введите ОЗУ (в МБ): " ram
    read -rp "Введите максимальный объем дискового пространства (в МБ): " disk_space
    read -rp "Введите ID локации: " locid

    cd "$PANEL_DIR" || { print_error "Каталог не найден"; return 1; }

    # Создание локации
    echo -e "$location_name\n$location_description" | php artisan p:location:make

    # Создание узла
    {
        echo "$node_name"
        echo "$location_description"
        echo "$locid"
        echo "https"
        echo "$domain"
        echo "yes"
        echo "no"
        echo "no"
        echo "$ram"
        echo "$ram"
        echo "$disk_space"
        echo "$disk_space"
        echo "100"
        echo "8080"
        echo "2022"
        echo "/var/lib/pterodactyl/volumes"
    } | php artisan p:node:make

    print_success "УЗЕЛ И МЕСТОПОЛОЖЕНИЕ СОЗДАНЫ УСПЕШНО"
    sleep 2
}

# Удаление панели
uninstall_panel() {
    print_header "УДАЛЕНИЕ ПАНЕЛИ"
    
    if bash <(curl -s "$PANEL_INSTALLER_URL") <<< $'y\ny\ny\ny'; then
        print_success "ПАНЕЛЬ УДАЛЕНА УСПЕШНО"
    else
        print_error "ОШИБКА УДАЛЕНИЯ ПАНЕЛИ"
    fi
    sleep 2
}

# Настройка Wings
configure_wings() {
    print_header "НАСТРОЙКА WINGS"
    
    read -rp "Введите токен для настройки Wings: " wings_token
    eval "$wings_token"
    sudo systemctl start wings
    
    print_success "WINGS НАСТРОЕН УСПЕШНО"
    sleep 2
}

# Создание аккаунта администратора
create_admin_account() {
    print_header "СОЗДАНИЕ АККАУНТА АДМИНИСТРАТОРА"
    
    read -rp "Введите имя пользователя: " username
    read -rp "Введите пароль: " password
    
    cd "$PANEL_DIR" || { print_error "Каталог не найден"; return 1; }
    
    echo -e "yes\nhackback@gmail.com\n$username\n$username\n$username\n$password" | \
    php artisan p:user:make
    
    print_success "АККАУНТ СОЗДАН УСПЕШНО"
    sleep 2
}

# Изменение пароля VPS
change_vps_password() {
    print_header "ИЗМЕНЕНИЕ ПАРОЛЯ VPS"
    
    read -rsp "Введите новый пароль: " password
    echo
    read -rsp "Повторите новый пароль: " password_confirm
    echo
    
    if [[ "$password" != "$password_confirm" ]]; then
        print_error "Пароли не совпадают"
        return 1
    fi
    
    echo -e "$password\n$password" | passwd
    
    print_success "ПАРОЛЬ VPS ИЗМЕНЕН УСПЕШНО"
    sleep 2
}

# Главное меню
main_menu() {
    while true; do
        clear
        print_header "ГЛАВНОЕ МЕНЮ"
        
        echo "ВЫБЕРИТЕ ДЕЙСТВИЕ:"
        echo "1. Установить тему"
        echo "2. Удалить тему"
        echo "3. Настройка Wings"
        echo "4. Создать узел"
        echo "5. Удалить панель"
        echo "6. Создать аккаунт администратора"
        echo "7. Изменить пароль VPS"
        echo "8. Выход"
        
        read -rp "Введите параметры (1-8): " choice
        
        case "$choice" in
            1) install_theme ;;
            2) uninstall_theme ;;
            3) configure_wings ;;
            4) create_node ;;
            5) uninstall_panel ;;
            6) create_admin_account ;;
            7) change_vps_password ;;
            8)
                echo "Выход из скрипта."
                cleanup
                exit 0
                ;;
            *)
                print_error "Неверный выбор, попробуйте еще раз"
                sleep 1
                ;;
        esac
    done
}

# Основная логика
main() {
    check_root
    check_dependencies
    display_welcome
    install_jq
    main_menu
}

# Обработка прерывания
trap 'cleanup; exit 0' INT TERM

# Запуск скрипта
main "$@"