# **Лабораторная работа №6**

## **Балансирование нагрузки и авто-масштабирование (AWS ALB + ASG + Terraform)**

## 1. Цель работы

Цель работы — освоить построение отказоустойчивой архитектуры веб-приложения в AWS, включающей:

* VPC с публичными и приватными подсетями
* веб-сервер на EC2 (nginx)
* создание AMI
* Application Load Balancer
* Target Group
* Auto Scaling Group
* мониторинг в CloudWatch
* автоматизацию инфраструктуры через Terraform

## 2. Постановка задачи

В рамках лабораторной необходимо:

1. Развернуть сетевую инфраструктуру.
2. Запустить веб-сервер на EC2 и проверить его работу.
3. Создать собственный AMI-образ.
4. Настроить балансировщик нагрузки (ALB).
5. Настроить Auto Scaling Group.
6. Выполнить нагрузочное тестирование веб-сервера.
7. Наблюдать метрики и автоматическое масштабирование.
8. Автоматизировать инфраструктуру при помощи Terraform.

## 3. Практическая часть

## 3.1 Часть 1 — выполненная в AWS UI вручную

Выбранный регион: eu-central-1 (Frankfurt):

![image](https://i.imgur.com/jk1AdZB.png)

### **3.1.1 Создание VPC и подсетей**

Через AWS Management Console вручную созданы:

* 1 VPC (`10.0.0.0/16`)
* 2 публичные подсети
* 2 приватные подсети
* Internet Gateway
* Route Table → маршрут `0.0.0.0/0 → igw`

VPC получилась полностью работоспособной и готовой для размещения ALB и ASG.

![image](https://i.imgur.com/kv0f1uO.png)

![image](https://i.imgur.com/ReiMitQ.png)

![image](https://i.imgur.com/bFXMuSH.png)

![image](https://i.imgur.com/BluGSVd.png)

### **3.1.2 Развёртывание EC2 и установка nginx**

Был развернут EC2-инстанс:

* AMI: Amazon Linux 2023
* Instance type: t3.micro
* Public IP: enabled
* Security Group:

  * SSH 22 — только мой IP
  * HTTP 80 — открыт для всех

В UserData был использован скрипт, устанавливающий nginx и создающий тестовую страницу.

Страница успешно открывалась по публичному IP инстанса.

![image](https://i.imgur.com/6YtOdlJ.png)

![image](https://i.imgur.com/Sy29Nte.png)

![image](https://i.imgur.com/XTOXxLh.png)

![image](https://i.imgur.com/dUCPb6f.png)

![image](https://i.imgur.com/MHFteTs.png)

![image](https://i.imgur.com/474slxy.png)

![image](https://i.imgur.com/eVX2ulY.png)

![image](https://i.imgur.com/4SMGhjt.png)

### **3.1.3 Создание AMI**

Из созданного EC2 был сделан образ:

```
lab6-webserver-ami
```

Этот AMI позже использовался Auto Scaling Group для запуска новых экземпляров.

![image](https://i.imgur.com/IVQfyCN.png)

## 3.2 Часть 2 — выполненная через Terraform

Вся остальная инфраструктура автоматизирована с помощью Terraform:

* Security Group для ALB
* Launch Template
* Target Group
* Application Load Balancer
* Listener
* Auto Scaling Group
* Scaling policy (CPU target tracking)
* Вывод DNS ALB

Ниже — объяснение каждого файла и ресурса.

## 4. Terraform Automation

## **4.1 main.tf — основной сценарий Terraform**

Этот файл создаёт всю логику балансировщика нагрузки и Auto Scaling.

```terraform
provider "aws" {
  region = "eu-central-1"
}

########################
# Security Group для ALB
########################
resource "aws_security_group" "alb_sg" {
  name        = "lab6-alb-sg"
  description = "Security group for lab6 ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# Launch Template
########################
resource "aws_launch_template" "web" {
  name_prefix   = "lab6-launch-template-"
  image_id      = var.ami_id
  instance_type = "t3.micro"

  # SG для самих web-инстансов — уже создан вручную
  vpc_security_group_ids = [var.instance_sg_id]

  monitoring {
    enabled = true
  }
}

########################
# Target Group
########################
resource "aws_lb_target_group" "tg" {
  name     = "lab6-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

########################
# Application Load Balancer
########################
resource "aws_lb" "alb" {
  name               = "lab6-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

########################
# Auto Scaling Group
########################
resource "aws_autoscaling_group" "asg" {
  name                = "lab6-asg"
  max_size            = 4
  min_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnet_ids  # приватные подсети

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 60

  metrics_granularity = "1Minute"
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
    "GroupMaxSize",
    "GroupMinSize",
  ]
}

########################
# Target Tracking по CPU
########################
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "lab6-cpu-target"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    target_value = 50

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
```

### **4.1.1 Security Group для ALB**

Открывает порт 80 в интернет, чтобы ALB был доступен снаружи.

Outgoing-трафик открыт полностью — по умолчанию ALB нужно свободно подключаться к EC2.

### **4.1.2 Launch Template**

В шаблоне указывается:

* AMI — созданный вручную образ `lab6-webserver-ami`
* тип инстанса
* Security Group
* включённый мониторинг CloudWatch

ASG всегда создаёт EC2 исключительно на базе Launch Template.

### **4.1.3 Target Group**

Группа, в которую ALB будет отправлять трафик.

Параметры:

* Port 80
* Protocol HTTP
* Health Checks: путь `/`, 200 OK

EC2, созданные ASG, автоматически регистрируются в этой TG.

### **4.1.4 Application Load Balancer**

Создаётся внешний (internet-facing) ALB:

* расположен в публичных подсетях
* получает трафик от пользователя
* перенаправляет его в Target Group

Listener 80 имеет действие:

```
default_action = "forward"
```

Это означает: весь трафик отправляется в target group.

### **4.1.5 Auto Scaling Group**

ASG автоматически создаёт EC2:

* min_size = 2
* max_size = 4
* desired_capacity = 2
* размещение — только в приватных подсетях

Также включён сбор метрик:

* GroupDesiredCapacity
* GroupInServiceInstances
* GroupTotalInstances
* GroupMinSize
* GroupMaxSize

Эти данные использовались для CloudWatch графиков.

### **4.1.6 Target Tracking Scaling Policy**

ASG автоматически поддерживает:

> **Среднюю загрузку CPU = 50%**

Если CPU растёт — создаются новые EC2.
Если нагрузка падает — количество EC2 уменьшается.

## **4.2 variables.tf — описание переменных**

```terraform
variable "vpc_id" {
  description = "ID of project-lab6-vpc"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for ASG"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID created from lab6-webserver"
  type        = string
}

variable "instance_sg_id" {
  description = "Security group ID for web instances (lab6-security-group)"
  type        = string
}
```

Переменные используются для передачи ID ресурсов, созданных вручную:

* vpc_id
* public_subnet_ids
* private_subnet_ids
* ami_id
* instance_sg_id

Terraform получает их из `terraform.tfvars`.

## **4.3 terraform.tfvars — реальные значения**

```terraform
vpc_id = "vpc-041029a4e1ab4e589"

public_subnet_ids = [
  "subnet-04926f608ab839658", # public1-eu-central-1a
  "subnet-08a84c8871299da57", # public2-eu-central-1b
]

private_subnet_ids = [
  "subnet-02692f5fff93a4c4b", # private1-eu-central-1a
  "subnet-0faac8e5991a08bde", # private2-eu-central-1b
]

ami_id         = "ami-059a5d6ba8c97921a"   # lab6 AMI
instance_sg_id = "sg-00c1d7cc65c4b8fd5"   # lab6-security-group
```

Файл содержит конкретные ID ресурсов, соответствующие моей инфраструктуре:

* ID VPC
* ID подсетей
* AMI
* Security Group

Terraform автоматически подхватывает эти значения.

## **4.4 outputs.tf**

```terraform
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}
```

![image](https://i.imgur.com/Mr0urh8.png)

![image](https://i.imgur.com/K85GuEV.png)

![image](https://i.imgur.com/o1d9nTO.png)

![image](https://i.imgur.com/mvx8ISu.png)

Выводит DNS-имя ALB после успешного `terraform apply`.

Это удобно для автоматического тестирования нагррузки.

## **4.5 curl.sh — скрипт нагрузки**

```shell
#!/bin/bash
set -e

if [ $# < 3 ]; then
    echo "Usage: $0 <alb_dns_name> <threads> <seconds>"
    echo "Example: $0 lab6-alb-1847776352.eu-central-1.elb.amazonaws.com 20 60"
    exit 1
fi

ALB_DNS="$1"
THREADS="$2"
SECONDS="$3"

TARGET="http://$ALB_DNS/load?seconds=$SECONDS"

echo "========================================="
echo " Starting load against: $TARGET"
echo " Threads: $THREADS"
echo " Duration: $SECONDS seconds"
echo "========================================="

END_TIME=$(( $(date +%s) + SECONDS ))

for ((i=1; i<=THREADS; i++)); do
    (
        while [ "$(date +%s)" -lt "$END_TIME" ]; do
            curl -s "$TARGET" > /dev/null || true
        done
    ) &
done

wait
echo "Load finished."
```

Скрипт создаёт многопоточную нагрузку на ALB:

1. Принимает:

   * DNS-имя ALB
   * количество потоков
   * длительность

2. Создаёт URL вида:

```
http://ALB/load?seconds=N
```

3. Запускает заданное количество фоновых потоков `curl`.

4. Каждый поток выполняет HTTP-запросы, пока не истечёт время.

Этот скрипт позволяет:

* нагружать CPU на EC2
* проверять корректность Target Tracking
* наблюдать автоматическое увеличение EC2 в ASG

## 5. Мониторинг и результаты тестирования

Для проверки работы Auto Scaling был запущен скрипт:

```
./curl.sh http://lab6-alb-1847776352.eu-central-1.elb.amazonaws.com 20 60
```

Наблюдения:

* CPU резко вырос
* alarm выпал в состояние `InAlarm`
* ASG увеличил количество EC2
* нагрузка распределялась через ALB
* после завершения нагрузки ASG уменьшил количество EC2

Графики, собранные в CloudWatch:

* CPUUtilization
* GroupInServiceInstances
* GroupDesiredCapacity
* GroupTotalInstances
* GroupMinSize / GroupMaxSize
* ALB Request Count

Графики в CloudWatch в состоянии без нагрузки:

![image](https://i.imgur.com/LuxAGdX.png)

Графики в CloudWatch в состоянии нагрузки (все вместе и по отдельности):

![image](https://i.imgur.com/AKiNC59.png)

![image](https://i.imgur.com/mn9nOR8.png)

![image](https://i.imgur.com/Hr8bCWY.png)

![image](https://i.imgur.com/saRdYQz.png)

## 6. Завершение работы

После получения всех графиков и подтверждения работы Auto Scaling были удалены:

* Load Balancer
* Target Group
* Auto Scaling Group
* EC2
* Launch Template
* AMI и snapshot
* VPC и подсети

![image](https://i.imgur.com/n7qy3Fd.png)

![image](https://i.imgur.com/Z83RBtO.png)

![image](https://i.imgur.com/JJakDNM.png)

![image](https://i.imgur.com/T0MKTGD.png)

![image](https://i.imgur.com/TDvtFNr.png)

![image](https://i.imgur.com/OYQZHhk.png)

Полная очистка ресурсов выполнилась успешно.

## 7. Ответы на контрольные вопросы

### 1. Что такое image и чем он отличается от snapshot? Какие есть варианты использования AMI?

AMI — полный образ виртуальной машины.
Snapshot — копия одного EBS-диска.
AMI используется для запуска EC2, ASG, миграции окружений.

### 2. Что такое Launch Template и зачем он нужен? Чем он отличается от Launch Configuration?

Launch Template содержит параметры EC2 (AMI, SG, тип, диски, user data).
Используется ASG.
Поддерживает версии, смешанные типы, T2/T3 Unlimited.
Launch Configuration — устарел и не поддерживается.

### 3. Зачем необходим и какую роль выполняет Target Group?

Служит связующим звеном между ALB и EC2.
Выполняет health-check и маршрутизацию к здоровым инстансам.

### 4. В чем разница между Internet-facing и Internal?

Internet-facing — доступен пользователям через интернет.
Internal — виден только внутри VPC.

### 5. Что такое Default action и какие есть типы Default action?

Default action — действие Listener'а, если правило не совпало.
Типы: forward, redirect, fixed-response.

### 6. Почему для Auto Scaling Group выбираются приватные подсети?

EC2 в ASG не должны иметь прямой доступ из интернета.
ALB принимает запросы, а приватные EC2 их обрабатывают.

### 7. Зачем нужна настройка Availability Zone distribution?

Обеспечивает равномерное распределение EC2 по зонам, повышая отказоустойчивость.

### 8. Что такое Instance warm-up period и зачем он нужен?

Время, которое ASG ждёт перед учётом нового инстанса — чтобы избежать ложного масштабирования из-за старта сервисов.

### 9. Какие IP-адреса вы видите и почему?

На странице выводится **внутренний приватный IP EC2**, потому что трафик идёт через ALB, а EC2 находятся в приватных подсетях.

### 10. Какую роль в этом процессе сыграл Auto Scaling?

Автоматически увеличивал и уменьшал количество EC2 на основе загрузки CPU, обеспечивая стабильность и отказоустойчивость системы.

## 8. Использованные источники

* [https://docs.aws.amazon.com](https://docs.aws.amazon.com)
* [https://registry.terraform.io/providers/hashicorp/aws/latest/docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* [https://aws.amazon.com/ec2/autoscaling/](https://aws.amazon.com/ec2/autoscaling/)
