# Лабораторная работа №2. Введение в AWS. Вычислительные сервисы

**Студент: Славов Константин, группа I2302** 

**Дата выполнения: 11.10.2025** 

**Регион AWS:** `eu-central-1 (Frankfurt)`

---

## 1. Описание лабораторной работы

### 1.1. Постановка задачи

Поднять простой веб‑сервер в AWS на базе EC2, настроить мониторинг и доступ по SSH, затем выполнить одно из практических развёртываний (статический сайт / PHP / Docker). В завершение остановить инстанс с помощью AWS CLI и ответить на контрольные вопросы.

### 1.2. Цель и этапы работы

**Цель:** получить базовые навыки работы с EC2, IAM, бюджетами и мониторингом в AWS; уметь развернуть веб‑приложение и корректно завершить работу ресурсов.

**Основные этапы (начато с Задания 3):**

* Задание 3 — создание EC2, настройка Security Group, User Data, проверка nginx.
* Задание 4 — базовый мониторинг и логирование (Status checks, Monitoring, System Log, Instance Screenshot).
* Задание 5 — подключение по SSH, проверка сервиса.
* Задание 6 — одно из развёртываний (в моем случае остановился на задании 6с).
* Задание 7 — завершение работы и удаление/остановка ресурсов через AWS CLI.

> Примечание: Задания 0–2 (подготовка аккаунта, IAM и бюджет) считаю выполненными заранее, т.к эти действия производились заранее на паре и я не вижу смысла добавлять какие-либо скриншоты в отчет.

---

## 2. Практическая часть

Ниже — разбор по пунктам, начиная с **Задания 3** (как в действительности была выполнена работа).

### Задание 3. Создание и запуск EC2 экземпляра

**Шаги выполнения**

1. Открыл сервис **EC2** → **Instances** → **Launch instances**.
2. Параметры:

   * **Name and tags:** `web-server`
   * **AMI:** *Amazon Linux 2023 AMI*
   * **Instance type:** `t3.micro` (Free Tier eligible)
   * **Key pair:** создан новый, в моем случае `kraaddys` (`.pem` сохранён локально)
   * **Security group:** `web-server-sg`

     * Inbound: `HTTP (80/tcp)` — Source: `0.0.0.0/0`
     * Inbound: `SSH (22/tcp)` — Source: `My IP`
   * **Network settings:** по умолчанию (VPC/Subnet auto)
   * **Storage:** по умолчанию
   * **Advanced details → User Data:**

     ```bash
     #!/bin/bash
     dnf -y update
     dnf -y install htop
     dnf -y install nginx
     systemctl enable nginx
     systemctl start nginx
     ```
3. Нажал **Launch instance**, дождался **Running** и **Status checks: 3/3**.
4. Открыл `http://<Public-IP>` — увидел стартовую страницу nginx.

**Ответ на контрольные вопросы (Задание 3)**

* **Что такое User Data и роль скрипта?** User Data — это стартовый сценарий инициализации (cloud‑init), который выполняется при первом запуске инстанса. Скрипт автоматизирует подготовку сервера (обновления, установка пакетов, включение и запуск nginx).
* **Для чего используется nginx?** Nginx — высокопроизводительный HTTP‑сервер и reverse‑proxy. В данной работе он отдаёт статический контент (или проксирует в PHP‑FPM/приложение), обеспечивая доступ к сайту по порту 80.

**Скриншоты выполненной работы:**

* Создание инстанса + EC2 → список инстансов (статус Running, 3/3 checks) + Карточка инстанса с Public IPv4

![image](https://i.imgur.com/ni6HHLh.png)
![image](https://i.imgur.com/iuLdnsp.png)
![image](https://i.imgur.com/KwT4oXF.png)
![image](https://i.imgur.com/YLg9MVI.png)
![image](https://i.imgur.com/U5NCDV2.png)
![image](https://i.imgur.com/eNM5oYc.png)

* Открытая стартовая страница nginx по `http://<Public-IP>`

![image](https://i.imgur.com/sbVDALS.png)

---

### Задание 4. Логирование и мониторинг

**4.1. Status checks**

* Проверил вкладку **Status checks** → все три теста *passed*:

**4.2. Monitoring (CloudWatch)**

* На вкладке **Monitoring** просмотрел метрики (CPUUtilization, NetworkIn/Out, DiskRead/Write Bytes). Увеличил графики через **Enlarge**.
* По умолчанию активен **Basic monitoring**.

**Ответ на вопрос:** Когда важен **Detailed monitoring**? — Когда нужна ближе к реальному времени телеметрия (1‑минутная гранулярность): для высоконагруженных систем, тонкой авто‑масштабируемости, оперативного алертинга и детального анализа производительности.

**4.3. System Log**

* **Actions → Monitor and troubleshoot → Get system log**. Нашёл строки cloud‑init об установке `nginx`, `htop`.
* Если лога нет — подождать и обновить.

**4.4. Instance Screenshot**

* **Actions → Monitor and troubleshoot → Get instance screenshot** — просмотрел снимок консоли ОС для диагностики возможных зависаний/ошибок ядра (полезно, если SSH недоступен).

**Скриншоты (добавлю фактические изображения):**

* Вкладка Status checks (3/3 passed) + Вкладка Monitoring с раскрытым графиком

![image](https://i.imgur.com/pUxwVfH.png)

* System Log с записями про установку пакетов

![image](https://i.imgur.com/H728U72.png)

* Instance Screenshot (вид консоли)

![image](https://i.imgur.com/EDlG6nt.png)

---

### Задание 5. Подключение к EC2 по SSH

**Шаги выполнения**

1. В терминале перешёл в директорию с ключом `.pem`:

   ```bash
   cd /путь/к/ключу
   ```

Настройку прав я выполнил, зайдя в папку с ключом, затем в `Свойства`. Там оставил доступ только для администратора и своей учетной записи.

3. Подключился:

   ```bash
   ssh -i kraaddys.pem ec2-user@<Public-IP>
   ```
4. Проверил статус nginx:

   ```bash
   systemctl status nginx
   ```

**Ответ на вопрос:** Почему в AWS нельзя использовать пароль для SSH?

* Для безопасности по умолчанию применяется **аутентификация по ключам**. Пароли уязвимы к брутфорсу и утечкам, ключи сложнее подобрать, их легко отзывать/ротационировать. Кроме того, cloud‑init автоматически разворачивает публичный ключ на инстансе, обеспечивая безпарольный вход.

**Скриншоты (добавлю фактические изображения):**

* Редактирование прав через `Свойства`

![image](https://i.imgur.com/L4vd6rv.png)

* Успешная SSH‑сессия

![image](https://i.imgur.com/DX3KkRW.png)

* Вывод `systemctl status nginx`

![image](https://i.imgur.com/W6KcRLR.png)

---

### Задание 6 (выбранный вариант - 6c)

#### 6c. PHP в Docker

**Установка Docker:**

```bash
sudo dnf -y install docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
```

Для того, чтобы удостовериться в правильной установке **Docker** прописал команду `docker --version`.

**docker-compose.yml (пример):**

```yaml
version: "3.9"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./app:/var/www/html:ro
    depends_on:
      - php
  php:
    image: php:8.2-fpm-alpine
    volumes:
      - ./app:/var/www/html
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: appdb
      MYSQL_USER: app
      MYSQL_PASSWORD: apppass
    volumes:
      - dbdata:/var/lib/mysql
  adminer:
    image: adminer
    ports:
      - "8080:8080"
volumes:
  dbdata:
```

**nginx.conf (пример):**

```nginx
server {
    listen 80;
    server_name _;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass php:9000;
    }
}
```

После всей настройки файлов, я поднял контейнер с одной из лабораторных с прошлого года по PHP (в моем случае лабораторная работа №4).

**Запуск:**

```bash
docker compose up -d
```

Проверка:

* `http://<Public-IP>` — приложение
* `http://<Public-IP>:8080` — Adminer

**Скриншоты:**

* Установка Docker на виртуальную машину

![image](https://i.imgur.com/ulNxL8e.png)

* Запуск Docker и проверка его версии

![image](https://i.imgur.com/t5UtDOr.png)

* Создание директории для клонирования проекта по PHP

![image](https://i.imgur.com/LUYZMFq.png)

* Поднятие контейнера при помощи команды `docker compose up -d`

![image](https://i.imgur.com/dcMci4q.png)

* Главная страница приложения и Adminer

![image](https://i.imgur.com/51lRosQ.png)
![image](https://i.imgur.com/N5daQH6.png)

---

### Задание 7. Завершение работы и удаление ресурсов (AWS CLI)

К сожалению, у меня не сохранились скриншоты данных шагов, но задание было выполнено также, как и было расписано в лабораторной работе.

**Ответ на вопрос:** Чем `Stop` отличается от `Terminate`?

* `Stop` — выключает виртуальную машину, **сохраняя** томи (EBS) и конфигурацию. Можно затем запустить снова; Public IP может измениться.
* `Terminate` — окончательно удаляет инстанс и связанные ресурсы (если том не помечен как `Delete on termination = false`). Восстановление невозможно.

---

## 4. Список использованных источников

* Документация AWS: EC2, IAM, Budgets, CloudWatch
* Задания из лабораторной работы (в качестве методички)
* [Nginx: официальная документация по конфигурации](https://nginx.org/en/docs/)
* [Docker & Compose: официальная документация](https://docs.docker.com/compose/)

---

## 5. Вывод

В ходе работы был развернут инстанс EC2 в регионе `eu-central-1`, также была произведена автоматизация установки nginx через User Data, после чего произведена проверка в доступности веб‑сервера, а также изучение базовых средств мониторинга (Status checks, CloudWatch) и подключение по SSH с использованием ключей. Далее был выполнен выбранный сценарий развёртывания (в разделе 6) и корректно остановлен инстанс через AWS CLI. В ходе лабораторной работы были получены практические навыки работы с ключевыми сервисами AWS и базовыми методами диагностики.
