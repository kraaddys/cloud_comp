# Лабораторная работа №4. Объектное хранилище Amazon S3

**Студент: Славов Константин, группа I2302**

**Дата: 31.10.2025**

**Регион AWS: `eu-central-1 (Frankfurt)`**

**k:** `18`  → `k%30 = 18`

## 1. Описание лабораторной работы

### 1.1. Постановка задачи

Познакомиться с сервисом Amazon S3 (Simple Storage Service) и отработать основные операции по работе с объектным хранилищем:
создание публичного и приватного бакетов, загрузку файлов, управление доступом через IAM и Bucket Policy, настройку версионирования, правил жизненного цикла и статического хостинга сайта.

### 1.2. Цели и основные этапы

**Цель:** освоить базовые принципы объектного хранилища AWS S3 и работу с ним как через консоль, так и через CLI.

**Этапы:**

1. Создание бакетов (публичного и приватного).
2. Настройка модели доступа `Bucket Owner Enforced` (без ACL).
3. Создание `IAM-пользователя` и политики минимальных прав.
4. Проверка доступа к `S3` через `AWS CLI`.
5. Настройка публичного чтения для контента.
6. Включение версионирования.
7. Создание Lifecycle-правил.
8. Развёртывание статического сайта на `S3`.

## 2. Практическая часть

### Шаг 1. Создание бакетов без ACL

1. Перешёл в **AWS Console → S3 → Create bucket**.

2. Создал **публичный бакет:**

* **Имя:** `cc-lab4-pub-k18`
* **Регион:** `eu-central-1`
* **Object Ownership:** `Bucket owner enforced (ACLs disabled)`
* **Block all public access:** `включено (пока)`
* **Нажал** `Create bucket`.

3. Повторно создал приватный бакет:

* **Имя:** `cc-lab4-priv-k18`
* **Object Ownership:** `Bucket owner enforced`
* **Block all public access:** `включено`

После создания оба бакета отображаются в списке `S3`.

![image](https://i.imgur.com/ewMPE6I.png)

![image](https://i.imgur.com/V5S8g33.png)

![image](https://i.imgur.com/z4fHCIv.png)

![image](https://i.imgur.com/l44hkS7.png)

![image](https://i.imgur.com/OQWxxv7.png)

**Контрольный вопрос:**

> **Что значит `Object Ownership: Bucket owner enforced?`**
> 
> **Ответ:** Это современная модель управления доступом без использования `ACL`. Все объекты принадлежат владельцу бакета, а управление доступом выполняется через `IAM и Bucket Policy`. Такой подход считается безопасным и корпоративным стандартом `AWS`.

### Шаг 2. Создание IAM-пользователя и политики минимальных прав

**2.1. Создание пользователя**

1. **IAM → Users → Create user.**

* **Имя:** `s3-uploader`

2. **Console access:** выключен (работа только через CLI).
3. Создан **access key** для CLI и сохранён `Access key ID` и `Secret access key`

**Скриншоты не прикреплял, чтобы не афишировать созданные ключи.**

![image](https://i.imgur.com/dAiQWVv.png)

![image](https://i.imgur.com/3hmlmBr.png)

![image](https://i.imgur.com/dgdT1or.png)

**Контрольный вопрос:**

> **Почему не стоит использовать root-учётную запись `AWS` для `CLI`?**
> 
> **Ответ:** Root-учётка имеет полный доступ ко всем ресурсам и предназначена только для администрирования. Для автоматизации и `CLI` безопаснее использовать отдельного `IAM-пользователя` с ограниченными правами.

**2.2. Создание IAM-политики**

**Policies → Create policy → JSON**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOnlyTheseBuckets",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::cc-lab4-pub-k18",
        "arn:aws:s3:::cc-lab4-priv-k18"
      ]
    },
    {
      "Sid": "ReadWritePublicBucketLimited",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::cc-lab4-pub-k18/*"
    },
    {
      "Sid": "LogsRWButOnlyUnderLogsPrefix",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::cc-lab4-priv-k18/logs/*"
    }
  ]
}
```

![image](https://i.imgur.com/rHmsUY4.png)

![image](https://i.imgur.com/XcMLChS.png)

**2.3. Привязка политики**

1. **IAM → Users → s3-uploader → Permissions → Add permissions.**
2. Выбрал политику `S3UploaderPolicy` → `Add permissions`

![image](https://i.imgur.com/KV2cpbK.png)

![image](https://i.imgur.com/k511dM3.png)

![image](https://i.imgur.com/ZAoon6C.png)

![image](https://i.imgur.com/ljHb92A.png)

**Контрольный вопрос:**

> **Почему AWS по умолчанию запрещает все действия?**
> 
> **Ответ:** AWS использует принцип `deny by default` — все операции запрещены, пока явно не разрешены политикой безопасности.

### Шаг 3. Настройка публичного доступа к контенту

1. **В публичном бакете:**
* `Permissions → Block public access → снять галочку "Block all public access"`
2. Затем в разделе `Bucket policy` вставил:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicRead",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": [
        "arn:aws:s3:::cc-lab4-pub-k18/avatars/*",
        "arn:aws:s3:::cc-lab4-pub-k18/content/*"
      ]
    }
  ]
}
```

![image](https://i.imgur.com/WYyAr1T.png)

![image](https://i.imgur.com/H6jWwLy.png)

![image](https://i.imgur.com/q1f12ho.png)

![image](https://i.imgur.com/eVu6hdY.png)

![image](https://i.imgur.com/XvU4R2P.png)

**Контрольный вопрос:**

> **Что означает `Principal: "*"` в политике?**
> 
> **Ответ:** Это означает, что доступ на чтение `(s3:GetObject)` открыт для всех пользователей интернета, без аутентификации.

### Шаг 4 и 5. Проверка работы через AWS CLI

1. Настроил CLI с помощью команды:

`aws configure`

После чего ввел данные для авторизации. Затем перешел в папку с проектом и начал загружать доступные файлы. После чего, в самом конце, проверил их доступность по `URL`.

![image](https://i.imgur.com/1P5Yamj.png)

![image](https://i.imgur.com/0YILyQv.png)

![image](https://i.imgur.com/qaHFFqC.png)

![image](https://i.imgur.com/sdgdT3y.png)

![image](https://i.imgur.com/YXLRTEk.png)

**Контрольный вопрос:**

> **Почему приватный bucket нельзя напрямую открыть по ссылке?**
> 
> **Ответ:** Потому что в нём отсутствует публичная политика `GetObject`, и все запросы без авторизации блокируются.

### Шаг 6. Версионирование объектов

1. В свойствах обоих бакетов включил `Versioning` → `Enable`
2. Загрузил изменённый файл `logo.png` повторно.
3. Вкладка `Versions` показывает две версии.

![image](https://i.imgur.com/pUjrnMF.png)

![image](https://i.imgur.com/1Y6ukvD.png)

![image](https://i.imgur.com/WlhIOZw.png)

![image](https://i.imgur.com/hm08yWO.png)

![image](https://i.imgur.com/ftjwj9z.png)

![image](https://i.imgur.com/tWScLlh.png)

![image](https://i.imgur.com/Te5ttCd.png)

**Контрольный вопрос:**

> **Что произойдёт, если выключить версионирование после его включения?**
> 
> **Ответ:** Версионирование перестанет создавать новые версии, но старые версии сохранятся и будут доступны до их явного удаления.

### Шаг 7. Lifecycle-правила (управление жизненным циклом данных)

1. Перешёл в **cc-lab4-priv-k18 → Management → Lifecycle rules → Create rule.**
2. Имя: `logs-archive`
3. Префикс: `logs/`

| Действие   | Переход / срок          | Класс хранения       |
|------------|-------------------------|----------------------|
| Transition | через 30 дней           | Standard-IA          |
| Transition | через 365 дней          | Glacier Deep Archive |
| Expiration | удалить через 1825 дней | —                    |

![image](https://i.imgur.com/CYp1vFO.png)

![image](https://i.imgur.com/iDhsql4.png)

![image](https://i.imgur.com/pIS6pds.png)

![image](https://i.imgur.com/KCJbOFn.png)

![image](https://i.imgur.com/UWfqSN5.png)

![image](https://i.imgur.com/hyX65zo.png)

**Контрольный вопрос:**

> **Что такое Storage Class в Amazon S3?**
> 
> **Ответ:** **Storage Class** определяет уровень доступности и стоимость хранения данных. Например, **Standard** — для активных файлов, **Glacier** — для архивов. Чем ниже частота доступа, тем дешевле хранение.

### Шаг 8. Статический веб-сайт на базе S3

1. Создал бакет **cc-lab4-web-k18**.
* Region: `eu-central-1`
* Object Ownership: `ACLs enabled`
* Block all public access: снял галочку.

2. Включил **Static website hosting** →
* Hosting type: `Host a static website`
* Index document: `index.html`

3. Загрузил файлы сайта (из архива методички).
4. Сделал файлы публичными и открыл URL: `http://cc-lab4-web-k18.s3-website.eu-central-1.amazonaws.com`

![image](https://i.imgur.com/BS7beRn.png)

![image](https://i.imgur.com/WOBAD9Q.png)

![image](https://i.imgur.com/Z6D9Bow.png)

![image](https://i.imgur.com/r6rfyrn.png)

![image](https://i.imgur.com/POf42X7.png)

![image](https://i.imgur.com/nScJRIP.png)

![image](https://i.imgur.com/JbraTFP.png)

![image](https://i.imgur.com/gE5HR42.png)

![image](https://i.imgur.com/tnRh9O0.png)

![image](https://i.imgur.com/PtUluAE.png)

![image](https://i.imgur.com/vaJindQ.png)

![image](https://i.imgur.com/BoqrNvD.png)

![image](https://i.imgur.com/QTE3r5N.png)

**Контрольный вопрос:**

> **Для чего используется S3 Static Website Hosting?**
> 
> **Ответ:** Для хостинга простых статических сайтов без серверов. S3 обслуживает HTML, CSS, JS-файлы напрямую из бакета, обеспечивая дешёвое и надёжное размещение контента.

**В ходе выполнения данной лабораторной работы я решил обойтись без выполнения дополнительного задания и остановился на поднятии статического веб-сайта при помощи Amazon S3.**

## 3. Вывод

В ходе лабораторной работы были созданы и настроены три бакета:

* `cc-lab4-pub-k18` — публичный, для контента;

* `cc-lab4-priv-k18` — приватный, с Lifecycle-правилом и версионированием;

* `cc-lab4-web-k18` — для статического сайта.

Был создан IAM-пользователь `s3-uploader` с ограниченными правами, настроены политики доступа, публичное чтение, версия объектов и автоматическое архивирование данных.
Проверена работа S3 через AWS CLI и веб-доступ.
Результатом стало полное понимание принципов работы Amazon S3, его политики безопасности, классов хранения и возможностей по хостингу статических сайтов.

## 4. Использованные источники

* [Amazon Simple Storage Service Documentation](https://docs.aws.amazon.com/s3/)
* [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/s3/)
* Методические материалы лабораторной работы №4 из Moodle и GitHub.