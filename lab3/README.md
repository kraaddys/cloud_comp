# Лабораторная работа №3. Облачные сети (AWS VPC)

**Студент: Славов Константин, группа I2302**

**Дата: 18.10.2025**

**Регион AWS:** `eu-central-1 (Frankfurt)`

**k:** `18`  → `k%30 = 18`

## 1. Описание лабораторной работы

### 1.1. Постановка задачи

Ручное построение изолированной сети в AWS: создание VPC, публичной и приватной подсетей, IGW и NAT Gateway, таблиц маршрутов и SG; развёртывание трёх EC2 (web, db, bastion) и проверка взаимодействия (web ↔ db через приватную подсеть, доступ наружу через NAT для приватных хостов).

### 1.2. Цели и основные этапы

**Цель:** освоить базовые сетевые примитивы AWS и отладку связности между подсетями и Интернетом.

**Этапы:**

1. Подготовка консоли (регион `eu-central-1`).
2. Создание VPC `student-vpc-k18` с адресным пространством `10.18.0.0/16`.
3. IGW `student-igw-k18` и его attach к VPC.
4. Публичная подсеть `public-subnet-k18` (`10.18.1.0/24`, `eu-central-1a`) и приватная `private-subnet-k18` (`10.18.2.0/24`, `eu-central-1b`).
5. Таблицы маршрутов: `public-rt-k18` (0.0.0.0/0 → IGW) и `private-rt-k18` (0.0.0.0/0 → NAT, после создания NAT).
6. NAT Gateway `nat-gateway-k18` в публичной подсети с Elastic IP.
7. Security Groups: `web-sg-k18`, `bastion-sg-k18`, `db-sg-k18`.
8. EC2: `web-server` (публичная), `db-server` (приватная), `bastion-host` (публичная) + User Data.
9. Проверка связности (HTTP к web, MySQL с bastion к db, yum/dnf в приватной подсети через NAT).
10. Дополнительно: SSH Agent Forwarding к приватному хосту через bastion.
11. Завершение: удаление/остановка ресурсов (во избежание затрат).

## 2. Практическая часть (пошагово)

### Шаг 1. Подготовка среды

* Вошёл в AWS Management Console.
* Регион вверху справа: `Frankfurt (eu-central-1)`.

![image](https://i.imgur.com/GXYsOul.png)

* Открыл сервис **VPC**.

### Шаг 2. Создание VPC

* `Your VPCs` → `Create VPC`:

  * **Name tag:** `student-vpc-k18`
  * **IPv4 CIDR block:** `10.18.0.0/16` (так как `k%30 = 18`)
  * **Tenancy:** Default
* Нажал `Create VPC` → VPC создана.

![image](https://i.imgur.com/Pw27ugq.png)
![image](https://i.imgur.com/IIhIcuR.png)

**Ответ (контрольный):** маска `/16` значит, что префикс сети — первые 16 бит, размер подсети — 65 536 адресов (≈65k). Почему не `/8`? Слишком крупная сеть (≈16 млн адресов), не рекомендуется и ограничено по best practices; дробление адресного пространства на разумные подсети упрощает маршрутизацию и безопасность.

### Шаг 3. Internet Gateway (IGW)

* `Internet Gateways` → `Create internet gateway`:

  * **Name:** `student-igw-k18`
* Выбрал IGW → `Actions` → `Attach to VPC` → `student-vpc-k18` → `Attach`.

**Пояснение:** IGW необходим для выхода в Интернет из VPC и приёма входящих соединений к публичным IP.

![image](https://i.imgur.com/x8rlaFo.png)
![image](https://i.imgur.com/GKOLz6c.png)
![image](https://i.imgur.com/RG4Iffw.png)
![image](https://i.imgur.com/Jik02lN.png)

### Шаг 4. Подсети (Subnets)

#### 4.1. Публичная подсеть

* `Subnets` → `Create subnet`:

  * **VPC ID:** `student-vpc-k18`
  * **Subnet name:** `public-subnet-k18`
  * **Availability Zone:** `eu-central-1a`
  * **IPv4 CIDR block:** `10.18.1.0/24`
* `Create subnet`.

**Контрольный вопрос:** является ли подсеть публичной уже сейчас? — Нет. Пока что это просто подсеть; публичной она станет после привязки таблицы маршрутов с маршрутом `0.0.0.0/0 → IGW` и (при необходимости) включённого Auto-assign Public IP для хостов.

![image](https://i.imgur.com/mrF67zk.png)
![image](https://i.imgur.com/hNjdzXH.png)

#### 4.2. Приватная подсеть

* `Create subnet` ещё раз:

  * **VPC ID:** `student-vpc-k18`
  * **Subnet name:** `private-subnet-k18`
  * **Availability Zone:** `eu-central-1b` (иная AZ для отказоустойчивости)
  * **IPv4 CIDR block:** `10.18.2.0/24`
* `Create subnet`.

**Контрольный вопрос:** является ли подсеть приватной уже сейчас? — Пока что нет; она станет «приватной» когда её таблица маршрутов **не** будет вести трафик напрямую в IGW, а для выхода в Интернет будет использоваться NAT (маршрут на NAT Gateway).

![image](https://i.imgur.com/AZ3zww1.png)
![image](https://i.imgur.com/qOfLDtI.png)

### Шаг 5. Таблицы маршрутов (Route Tables)

#### 5.1. Публичная RT

* `Route Tables` → `Create route table`:

  * **Name tag:** `public-rt-k18`
  * **VPC:** `student-vpc-k18`
* Открыл `public-rt-k18` → вкладка **Routes** → `Edit routes` → `Add route`:

  * **Destination:** `0.0.0.0/0`
  * **Target:** `Internet Gateway (student-igw-k18)`
* `Save changes`.
* Вкладка **Subnet associations** → `Edit subnet associations` → отметил `public-subnet-k18` → `Save`.

**Зачем ассоциация?** Чтобы именно эта подсеть использовала данную RT и получила выход `0.0.0.0/0 → IGW`, став «публичной».

![image](https://i.imgur.com/Pgdn6DX.png)
![image](https://i.imgur.com/ScYxCVu.png)
![image](https://i.imgur.com/C7BeUvv.png)
![image](https://i.imgur.com/2IAHD3R.png)

#### 5.2. Приватная RT

* `Create route table`:

  * **Name tag:** `private-rt-k18`
  * **VPC:** `student-vpc-k18`
* Вкладка **Subnet associations** → `Edit subnet associations` → отметил `private-subnet-k18` → `Save`.
* Пока маршрут на Интернет здесь **не добавляем** — дождёмся NAT.

![image](https://i.imgur.com/3nn0ANc.png)
![image](https://i.imgur.com/8R9MLzN.png)
![image](https://i.imgur.com/jfMPR8u.png)
![image](https://i.imgur.com/A7TUYMV.png)

### Шаг 6. NAT Gateway

#### 6.1. Elastic IP

* `Elastic IPs` → `Allocate Elastic IP address` → `Allocate`.

#### 6.2. Создание NAT

* `NAT Gateways` → `Create NAT gateway`:

  * **Name tag:** `nat-gateway-k18`
  * **Subnet:** `public-subnet-k18`
  * **Connectivity type:** `Public`
  * **Elastic IP allocation ID:** выбрал созданный EIP
* `Create NAT gateway` → дождался статуса `Available`.

![image](https://i.imgur.com/t5aAFrb.png)
![image](https://i.imgur.com/Q85TcTi.png)

#### 6.3. Маршрут из приватной RT на NAT

* `Route Tables` → `private-rt-k18` → **Routes** → `Edit routes` → `Add route`:

  * **Destination:** `0.0.0.0/0`
  * **Target:** `NAT Gateway (nat-gateway-k18)`
* `Save changes`.

![image](https://i.imgur.com/7iXuWsH.png)
![image](https://i.imgur.com/DEw4813.png)
![image](https://i.imgur.com/esMvZIP.png)

**Ответ (контрольный):** как работает NAT Gateway? — Хосты приватной подсети отправляют внешний трафик к NAT; NAT подменяет исходный адрес на свой публичный EIP и маршрутизирует в Интернет через IGW. Ответы возвращаются на NAT, а затем в приватные хосты. Входящих соединений извне к приватным хостам NAT не пропускает.

### Шаг 7. Security Groups (SG)

* `Security Groups` → `Create security group` для каждой группы.

**`web-sg-k18`** (VPC: `student-vpc-k18`):

* **Inbound:**

  * HTTP `80/tcp` — `0.0.0.0/0`
  * HTTPS `443/tcp` — `0.0.0.0/0`
* **Outbound:** (по умолчанию `All traffic` — оставить)

![image](https://i.imgur.com/oxAtf6s.png)

**`bastion-sg-k18`**:

* **Inbound:**

  * SSH `22/tcp` — `My IP` (текущий внешний IP)

![image](https://i.imgur.com/JTNx8ST.png)

**`db-sg-k18`**:

* **Inbound:**

  * MySQL/Aurora `3306/tcp` — **Source:** `web-sg-k18`
  * MySQL/Aurora `3306/tcp` — **Source:** `bastion-sg-k18`
  * SSH `22/tcp` — **Source:** `bastion-sg-k18`

![image](https://i.imgur.com/9308GCi.png)

**Контрольный:** что такое Bastion Host? — Публичный «шлюзовой» сервер для безопасного админ‑доступа в приватные подсети (через SSH‑туннелирование/прокси). Исключает прямое открытие портов приватных хостов в Интернет.

### Шаг 8. EC2-инстансы

*Общее:* AMI `Amazon Linux 2`, тип `t3.micro`, ключ `student-key-k18`, диск 8 ГБ, тег `Name`.

**`web-server`** (публичная):

* **Network:** VPC `student-vpc-k18`, Subnet `public-subnet-k18` (`eu-central-1a`)
* **Auto-assign Public IP:** Enable
* **Security Group:** `web-sg-k18`
* **User data:**

```bash
#!/bin/bash
dnf -y install httpd php
cat > /var/www/html/index.php <<'PHP'
<?php phpinfo(); ?>
PHP
systemctl enable httpd
systemctl start httpd
```

![image](https://i.imgur.com/j60ypb6.png)
![image](https://i.imgur.com/QcSc67m.png)
![image](https://i.imgur.com/eXGPHG7.png)
![image](https://i.imgur.com/DKctrDU.png)
![image](https://i.imgur.com/P9YUAvW.png)

**`db-server`** (приватная):

* **Network:** VPC `student-vpc-k18`, Subnet `private-subnet-k18` (`eu-central-1b`)
* **Auto-assign Public IP:** Disable
* **Security Group:** `db-sg-k18`
* **User data:**

```bash
#!/bin/bash
dnf -y install mariadb105-server
systemctl enable mariadb
systemctl start mariadb
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'StrongPassword123!'; FLUSH PRIVILEGES;"
```

![image](https://i.imgur.com/zYQujrh.png)
![image](https://i.imgur.com/FM82wAx.png)
![image](https://i.imgur.com/I2HF6nW.png)
![image](https://i.imgur.com/wYEgEnL.png)
![image](https://i.imgur.com/9gm1mPe.png)

**`bastion-host`** (публичная):

* **Network:** VPC `student-vpc-k18`, Subnet `public-subnet-k18`
* **Auto-assign Public IP:** Enable
* **Security Group:** `bastion-sg-k18`
* **User data:**

```bash
#!/bin/bash
dnf -y install mariadb105
```

![image](https://i.imgur.com/LlqBYzA.png)
![image](https://i.imgur.com/1lXiGXI.png)
![image](https://i.imgur.com/5yNi2Pm.png)
![image](https://i.imgur.com/LFUCpeI.png)
![image](https://i.imgur.com/K6UIDDm.png)

### Шаг 9. Проверка

1. Дождался `running` и `3/3 checks` для всех.

![image](https://i.imgur.com/Mg2DeHe.png)

2. Открыл в браузере `http://<web-public-ip>` — страница `phpinfo()` отображается.

![image](https://i.imgur.com/MZefd4O.png)

3. Подключился на bastion по SSH + проверил Интернет с bastion:

```bash
ssh -i student-key-k18.pem ec2-user@<Bastion-Host-Public-IP>
ping -c 4 google.com
```

![image](https://i.imgur.com/Hb1XnMy.png)

Далее была произведена установка `MariaDB`, ее запуск и проверка статуса активности. 

![image](https://i.imgur.com/QeA3A2B.png)

Затем была произведена проверка порта 3306 на работоспособность.

![image](https://i.imgur.com/hcWqfmi.png)

5. С bastion к db по приватному IP:

```bash
mysql -u root -p
# пароль: StrongPassword123!
```

![image](https://i.imgur.com/08YZpRz.png)

После подключения к БД был создан пользователь, ему был задан пароль и присвоен определенный IP-адрес для дальнейшего подключения к bastion.

![image](https://i.imgur.com/nMEf5DQ.png)

Далее я создал базу данных, задача который было отображение статуса подключения БД к bastion. Это делалось, потому что в ходе выполнения лабораторной работы были проблемы с подключением и таким образом было решено проверить состояние подключения.

![image](https://i.imgur.com/6tZlsBQ.png)

И наконец после создания пользователя было снова проверено подключение к БД. На этот раз все получилось как необходимо.

![image](https://i.imgur.com/X3Bfiv0.png)

Успешное подключение подтверждает маршрутизацию внутри VPC и доступность `3306/tcp` от `bastion-sg-k18` к `db-sg-k18`. Для выхода в Интернет с приватных хостов (например, `dnf update`) используется NAT.

### Шаг 10. Дополнительно — SSH через Bastion (Agent Forwarding)

На локальной машине:

```bash
eval "$(ssh-agent -s)"
ssh-add student-key-k18.pem
ssh -A -J ec2-user@<Bastion-Host-Public-IP> ec2-user@<DB-Server-Private-IP>
```

**Контрольный:** `-A` включает переадресацию SSH‑агента (ключ остаётся локально, а удалённые хосты используют проксированный агент). `-J` — jump‑host (ProxyJump), то есть подключение к конечной машине через посредника (bastion).

![image](https://i.imgur.com/2UsH6DS.png)
![image](https://i.imgur.com/EBnvstT.png)

На `db-server` проверил доступ в Интернет через NAT:

```bash
sudo dnf -y update
sudo dnf -y install htop
```

Если команды завершились успешно — NAT работает.

![image](https://i.imgur.com/ZpjVTw4.png)
![image](https://i.imgur.com/106ErSU.png)

Завершил сессию и убил агент локально:

```bash
ssh-agent -k
```

![image](https://i.imgur.com/xvl83bq.png)

## 4. Завершение работы (удаление/остановка)

1. Удаление инстансов:

![image](https://i.imgur.com/yU6o1G9.png)
![image](https://i.imgur.com/jxvhxUm.png)

2. Удаление NAT Gateway:

![image](https://i.imgur.com/L7cxNBL.png)
![image](https://i.imgur.com/r121MVX.png)

3. Release Elastic IP-адресов:

![image](https://i.imgur.com/DccTmER.png)
![image](https://i.imgur.com/lCt3w5e.png)

4. Удаление Security Groups:

![image](https://i.imgur.com/ETBkzBL.png)
![image](https://i.imgur.com/oMgUuhC.png)

5. Detach и удаление Internet Gateway:

![image](https://i.imgur.com/oOLXSGb.png)
![image](https://i.imgur.com/u5cJvcp.png)
![image](https://i.imgur.com/ZIwmdXD.png)
![image](https://i.imgur.com/Nx1A40w.png)

6. Удаление VPC:

![image](https://i.imgur.com/Xn4KGYS.png)
![image](https://i.imgur.com/8UirDSo.png)

## 6. Вывод

В данной лабораторной работе была построена VPC `student-vpc-k18` с двумя подсетями: публичной `10.18.1.0/24` и приватной `10.18.2.0/24`. Настроены IGW, NAT Gateway с EIP, отдельные RT для каждой подсети. Созданы SG с минимально необходимыми правилами. Развёрнуты три EC2‑инстанса: `web-server` (HTTP/80 доступен извне), `db-server` (приватный, доступен по MySQL/3306 с web и bastion), `bastion-host` (SSH‑шлюз). Проверена связность, доступность Интернета из приватной подсети через NAT и админ‑доступ через bastion. Ресурсы корректно финализированы для исключения затрат.

