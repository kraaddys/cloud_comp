# Лабораторная работа №5

**Облачные базы данных AWS: Amazon RDS (MySQL) + Read Replica + подключение с EC2**

## 1. Цель работы

Целью лабораторной работы является изучение облачных сервисов баз данных Amazon Web Services (AWS), а именно:

* создание и настройка реляционной базы данных Amazon RDS на MySQL;
* настройка сетевой инфраструктуры (VPC, Subnets, Security Groups);
* создание Read Replica для повышения производительности и отказоустойчивости;
* подключение базы данных к виртуальной машине EC2;
* выполнение CRUD-операций в базе данных;
* *(дополнительно выполнено)* — автоматизация инфраструктуры с помощью Terraform.

---

## 2. Постановка задачи

В рамках лабораторной работы необходимо:

1. Создать частную облачную VPC с публичными и приватными подсетями.
2. Настроить две группы безопасности:

   * для веб-приложения (EC2);
   * для базы данных (RDS MySQL).
3. Создать Subnet Group и развернуть основной сервер RDS MySQL в приватной подсети.
4. Создать виртуальную машину EC2 для подключения к базе.
5. Подключиться к базе и создать таблицы, связанные по принципу *one-to-many*.
6. Создать Read Replica и проверить работу чтения/записи.
7. *(Дополнительно)* — автоматизировать создание инфраструктуры в Terraform.

---

## 3. Практическая часть

### 3.1. Создание VPC, подсетей и Security Groups

В AWS была создана инфраструктура:

| Компонент                                          | Конфигурация                                     |
| -------------------------------------------------- | ------------------------------------------------ |
| **VPC**                                            | `project-vpc`, CIDR: `10.0.0.0/16`               |
| **Публичные подсети**                              | `10.0.1.0/24`, `10.0.2.0/24`                     |
| **Приватные подсети**                              | `10.0.11.0/24`, `10.0.12.0/24`                   |
| **Internet Gateway**                               | Подключён к VPC                                  |
| **NAT Gateway**                                    | Для выхода приватных подсетей в интернет         |
| **Security Group EC2 (`web-security-group`)**      | HTTP 80, SSH 22                                  |
| **Security Group RDS (`db-mysql-security-group`)** | Вход TCP 3306 только от `web-security-group`     |
| **Subnet Group**                                   | `project-rds-subnet-group` (2 приватные подсети) |

![image](https://i.imgur.com/nFyA0AH.png)

![image](https://i.imgur.com/UCCnX4M.png)

![image](https://i.imgur.com/8C93k7I.png)

![image](https://i.imgur.com/8C93k7I.png)

![image](https://i.imgur.com/ia2l19M.png)

#### Контрольный вопрос

> **Что такое Subnet Group? И зачем необходимо создавать Subnet Group для базы данных?**

Subnet Group — это набор выбранных подсетей внутри одного VPC, из которых сервис Amazon RDS может выбрать место размещения экземпляра базы данных. В неё обязательно входят подсети в разных зонах доступности, что позволяет базе оставаться доступной при отказе одной зоны. Subnet Group создаётся для того, чтобы RDS могла безопасно размещаться только в разрешённых приватных подсетях и обеспечивала отказоустойчивость и защиту от прямого доступа из интернета.

### Создание Security Group

![image](https://i.imgur.com/dVSWR3V.png)

![image](https://i.imgur.com/YB9COmD.png)

![image](https://i.imgur.com/5NqhbbX.png)

![image](https://i.imgur.com/LYAfWNv.png)

### Создание DB Subnet Group

![image](https://i.imgur.com/OAeUtei.png)

![image](https://i.imgur.com/zp2cuPD.png)

![image](https://i.imgur.com/YA12kdT.png)

---

### 3.2. Создание базы данных Amazon RDS MySQL

Параметры:

| Параметр        | Значение                        |
| --------------- | ------------------------------- |
| Engine          | MySQL 8.0.42                    |
| Instance Class  | `db.t3.micro`                   |
| Public Access   | **No**                          |
| Storage         | 20 GB GP3, autoscaling до 100GB |
| Initial DB name | `project_db`                    |
| Username        | `admin`                         |
| Backup          | **Enabled** (для реплики)       |

После запуска скопирован endpoint для дальнейшего подключения.

![image](https://i.imgur.com/ChTlbaZ.png)

![image](https://i.imgur.com/sypiQ2e.png)

![image](https://i.imgur.com/3mdS4sQ.png)

![image](https://i.imgur.com/yd5ro2h.png)

![image](https://i.imgur.com/icm01rI.png)

![image](https://i.imgur.com/u3CkAqx.png)

![image](https://i.imgur.com/to7Bf2O.png)

![image](https://i.imgur.com/fWYI41E.png)

![image](https://i.imgur.com/LMiq0Y7.png)

![image](https://i.imgur.com/CvndVwA.png)

---

### 3.3. Создание EC2 и подключение к БД

#### Подключение по SSH

```bash
ssh -i lab5-key.pem ec2-user@<EC2_PUBLIC_IP>
```

Установка MySQL-клиента:

```bash
sudo dnf update -y
sudo dnf install -y mariadb105
```

#### Подключение к базе RDS

```bash
mysql -h <RDS_ENDPOINT> -u admin -p
```

---

### 3.4. CRUD в базе данных

Выбрана база данных:

```sql
USE project_db;
```

#### Создание таблиц (One-to-Many)

```sql
CREATE TABLE categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50)
);

CREATE TABLE todos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255),
  category_id INT,
  status VARCHAR(50),
  FOREIGN KEY (category_id) REFERENCES categories(id)
);
```

#### Добавление данных

```sql
INSERT INTO categories (name) VALUES ('Home'), ('Work'), ('Study');

INSERT INTO todos (title, category_id, status) VALUES
('Buy milk', 1, 'pending'),
('Deploy RDS instance', 2, 'in-progress'),
('Prepare lab report', 3, 'pending');
```

#### Выборка данных с JOIN

```sql
SELECT t.id, t.title, c.name AS category, t.status
FROM todos t
JOIN categories c ON t.category_id = c.id;
```

**Результат:**

| id | title               | category | status      |
| -- | ------------------- | -------- | ----------- |
| 1  | Buy milk            | Home     | pending     |
| 2  | Deploy RDS instance | Work     | in-progress |
| 3  | Prepare lab report  | Study    | pending     |

![image](https://i.imgur.com/iw3kp34.png)

![image](https://i.imgur.com/TtfdALF.png)

![image](https://i.imgur.com/Q4d2iA3.png)

![image](https://i.imgur.com/LH2Mwxx.png)

![image](https://i.imgur.com/3sT9MQX.png)

![image](https://i.imgur.com/Gc7wW5L.png)

![image](https://i.imgur.com/xfEpv9j.png)

![image](https://i.imgur.com/2JnWv9M.png)

![image](https://i.imgur.com/9tkVh0S.png)

---

### 3.5. Создание и проверка Read Replica

Read Replica была создана в той же VPC, с той же SG.

![image](https://i.imgur.com/AJtzdsR.png)

![image](https://i.imgur.com/Xkq6V1a.png)

![image](https://i.imgur.com/Vin7uBF.png)

![image](https://i.imgur.com/ltkDyWb.png)

![image](https://i.imgur.com/BhhdhVD.png)

![image](https://i.imgur.com/gXgg01c.png)

#### Контрольный вопрос

> **Какие данные вы видите при SELECT на реплике? Почему?**

Реплика отображает те же данные, что и основная база. Это происходит потому, что Read Replica автоматически получает копию всех изменений, которые происходят на Primary-сервере. Реплика синхронизируется через механизм асинхронной репликации, поэтому данные становятся идентичными, хотя иногда с небольшой задержкой.

#### Попытка записи на реплике

```sql
INSERT INTO categories (name) VALUES ('ReplicaTest');
```

Результат: **ошибка**, запись невозможна.

> **Получилось ли выполнить запись на Read Replica? Почему?**

Запрос на запись (INSERT, UPDATE или DELETE) на Read Replica выполнить невозможно. Реплика предназначена только для чтения и используется для разгрузки основной базы. AWS специально запрещает запись на реплику, чтобы избежать конфликтов и несогласованности данных между основной и вторичной базами.

#### Добавление записи на Primary и обновление реплики

После `INSERT` на Primary запись через некоторое время появилась на Read Replica.

> **Отобразилась ли новая запись на реплике? Объясните почему.**

Да, новая запись со временем появляется на реплике. Это происходит благодаря работе механизма асинхронной репликации в MySQL: основная база записывает изменения в бинарный лог, а реплика считывает и применяет эти изменения у себя. Поэтому данные на реплике обновляются автоматически после выполнения изменений на Primary.

> **Зачем нужны Read Replicas и в каких сценариях их использование будет полезным?**

Read Replicas используются для масштабирования баз данных и повышения производительности систем, которые выполняют большое количество операций чтения. Часть SELECT-запросов можно отправлять на реплику, чтобы основная база не перегружалась и могла быстрее выполнять операции записи. Реплики полезны при аналитических запросах, статистике, чтении истории операций, а также могут использоваться как резерв для переключения в случае отказа основной базы. Их применение повышает скорость работы приложения и его отказоустойчивость.

---

### 3.6. Веб-приложение и подключение к RDS

На EC2 был установлен веб-сервер Apache+PHP:

```bash
sudo dnf install -y httpd php php-mysqlnd
sudo systemctl enable --now httpd
```

![image](https://i.imgur.com/yFrBLki.png)

![image](https://i.imgur.com/lZWs0dh.png)

![image](https://i.imgur.com/1gG5ouk.png)

---

### 3.7. Автоматизация инфраструктуры (Terraform)

Инфраструктура (VPC + Subnets + NAT + EC2 + RDS + SG) была описана в `main.tf`.

После чего выполнено:

```bash
terraform plan
terraform apply
```

![image](https://i.imgur.com/MPsPExu.png)

![image](https://i.imgur.com/oYzHbPR.png)

После завершения лабораторной работы выполнено удаление ресурсов:

```bash
terraform destroy
```

---

## 4. Вывод

В ходе лабораторной работы был изучен и применён на практике сервис Amazon RDS MySQL. Были созданы и настроены VPC, приватные и публичные подсети, группы безопасности, основной сервер базы данных и Read Replica. Выполнено подключение с виртуальной машины EC2, создание таблиц, CRUD-операции, тестирование репликации. Дополнительно выполнена Terraform-автоматизация инфраструктуры. Результатом работы стало полноценное распределённое приложение с separation of read/write workloads, что повышает масштабируемость и отказоустойчивость.

---

## 5. Использованные источники

* Официальная документация AWS: [https://docs.aws.amazon.com](https://docs.aws.amazon.com)
* AWS RDS User Guide: [https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)
* Terraform AWS Provider: [https://registry.terraform.io/providers/hashicorp/aws/latest/docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
