provider "aws" {
    region = "us-east-1" 
 }
      
    
#creamos una virtual Private Cloud(VPC). Una red virtual aislada
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16" #Definimos el rango de direcciones IP
    enable_dns_hostnames = true #Habilitamos los nombres de host DNS para las instancias en esta VPC

    tags = {
      Name = "main-vpc" #Estamos etiquetando a VPC para indentificarlo facilmenente
    } 
}

#creamos una subred publica dentro de VPC
resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id   #asociamos la subred con nuestra VPC
    cidr_block = "10.0.1.0/24" #definir rango de direciones IP para subred
    availability_zone = "us-east-1a" #especificacion de la zona de disponibilidad para la subred

    tags = {
      Name = "Public-subnet" #etiquetamos
    }
}

#creamos  un gateway
resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id #Asociamos el internet con nuestro VPC

    tags = {
        Name = "main-igw"
    }
  
}

#crear una tabla de rutas para nuestra subred publica.check"
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0" #esta ruta envia todo el trafico no local al gateway
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
      Name = "public-rt"
    }
  
}
 #Asociamos la tabla de rutas  con nuestra subred publica
 resource "aws_route_table_association" "public" {
    subnet_id   = aws_subnet.public.id
    route_table_id = aws_route_table.public.id    
}

#creamos un grupo de seguridad para nuestro servidor web
#un grupo de seguridad actua como un firewall virtual 
resource "aws_security_group" "web" {
    name = "allow_web"
    description = "Allow web inbound traffic"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "SSH from anywhere"
        from_port = 22 # <====== permitimos trafico HTTP entrante
        to_port = 22
        protocol = "tcp" #que aplique todos los protocolos
        cidr_blocks = ["0.0.0.0/0"] #permitimos trafico desde cualquier direccion IP
    }

    ingress {
        description = "HTTP from anywhere"
        from_port = 80 # <====== permitimos trafico HTTP entrante
        to_port = 80
        protocol = "tcp" #que aplique todos los protocolos
        cidr_blocks = ["0.0.0.0/0"] #permitimos trafico desde cualquier direccion IP
    }

    ingress {
        description = "HTTPS from anywhere"
        from_port = 443 # <====== permitimos trafico HTTP entrante
        to_port = 443
        protocol = "tcp" #que aplique todos los protocolos
        cidr_blocks = ["0.0.0.0/0"] #permitimos trafico desde cualquier direccion IP
    }

    ingress {
        description = "Flask default port"
        from_port = 5000 # <====== permitimos trafico HTTP entrante
        to_port = 5000
        protocol = "tcp" #que aplique todos los protocolos
        cidr_blocks = ["0.0.0.0/0"] #permitimos trafico desde cualquier direccion IP
    }

    egress {
        from_port = 0 # <========= permitimos todo el trafico saliente
        to_port = 0
        protocol = "-1" # significa todos los protocolos
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "allow_web"
    }
  
}
# obtener dinamicamente la IMS mas reciente
data "aws_ami" "amazon_linux_2" {
    most_recent = true
    owners = ["amazon"]

    filter {
      name = "name"
      values = ["amzn2-ami-hvm-*x86_64-gp2"]
    }
}
#crear un nuevo key pair
resource "aws_key_pair" "deployer" {
  key_name = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCivIyDbt2iGiS/T4MnD8yvX24jsAkc0PB9x/Fr8S8X5G3tcm12ut8kY60p860FdIhd74f0XHU+Ao31nhp/jw96hRI51UDthIEjaS92YCSvEujkNr85KwS9R8zjztWMUGFLkj0LprszmZTKpauws9GccNRigAgAJlmxWphrD/bUBt7/2zTVUQitmBZRG5xMyDlDN6hGWCQkWt+kuLwlz44rfyxPll2dWfhwwc1x9AK6Atg5cf4iEwOXYgPG3ZVc9z5nElYJBrWELtItsJg6TIf7YwCBXLo3ou4yufscEjqycogLikEf7kv77CWxEq3lKzYnV1GoQzOGR558HRiMjuBnpB9peeYlNE2nQUTBc2blm8u7IFW2ChLwhjGaZ/VcExnSPOoxhwDgJjiXY643HzoIeVMS4vLIafiacy1zkbXmi2jL1e2yI/8a8IwYE3vDQmjnW6tqzicDv3+JHNHOri1nx1PC13VXNJU52AHLRb2sy0qlS7Z9WlX3koNzfGvKqDe+vzJdqwrP7Tu6JlXEVicmBYUEzrZ69hsOn+FMDlR/rTYCCsxFJmhc0VevDvp2SDwrZyMAIITRGGnUza49NA+Y0ze20hO1+DZ+ONozFiGIb2CR55gWMHoG1Rc6P/qmfHpWh5FmhzrboAo9eVOzXqu2XwYJOmZrZQkw7dIgVyZ0Nw== victorzptzu@gmail.com"

}

# crear una instancia EC2 (un servidor virtual) en AWS
resource "aws_instance" "web" {
  ami = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro" #tipo de instancia (tamaño del servidor)
  subnet_id = aws_subnet.public.id # colocamos la instancia en nuestra subred publica
  vpc_security_group_ids = [aws_security_group.web.id] #asociar nuestro grupo de seguridad
  associate_public_ip_address = true   #asignamos una IP publica a nuestra instancia
  key_name = aws_key_pair.deployer.key_name

  user_data = <<-EOF
              #!bin/bash
              echo "ec2-user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ec2-user
              sudo chmod 440 /etc/sudoers.d/ec2-user
              EOF

  tags = {
    Name = "web-server"
  }
}

#Definir una salida para obtener la IP publica de nuestra instancia
# esto me va permitir conectarme facilmente con el servidor 
output "public_ip" {
    value = aws_instance.web.public_ip
    description = "La direccion IP publica del servidor web"
  
}