# MARTHA Arm

Entorno de desarrollo y simulación del brazo robótico **MARTHA** (RoboCup) con
**ROS 2 Humble**, **Gazebo Classic 11** y **MoveIt 2**, todo dentro de Docker.
No necesitas instalar ROS en tu equipo: solo Docker y, si tienes GPU NVIDIA,
el NVIDIA Container Toolkit.

---

## Tabla de contenidos

1. [Estructura del repositorio](#1-estructura-del-repositorio)
2. [Requisitos](#2-requisitos)
3. [Instalación en el anfitrión (host)](#3-instalación-en-el-anfitrión-host)
4. [Clonar y configurar el proyecto](#4-clonar-y-configurar-el-proyecto)
5. [Construir y levantar el contenedor](#5-construir-y-levantar-el-contenedor)
6. [Verificar que todo funciona](#6-verificar-que-todo-funciona)
7. [Compilar el workspace](#7-compilar-el-workspace)
8. [Uso diario](#8-uso-diario)
9. [Variables de configuración](#9-variables-de-configuración)
10. [Solución de problemas](#10-solución-de-problemas)

---

## 1. Estructura del repositorio

```
martha_arm/
├── README.md
├── sim.sh                  # Script de ayuda para lanzar la simulación
├── ros2_ws/                # Workspace de ROS 2 (se monta dentro del contenedor)
│   └── src/
└── docker/
    ├── Dockerfile          # Imagen: ROS 2 Humble + Gazebo + MoveIt 2
    ├── entrypoint.sh       # Carga ROS 2, Gazebo y el workspace
    ├── compose.yaml        # Configuración base (red, X11, volúmenes)
    ├── compose.nvidia.yaml # Override para GPU NVIDIA
    └── compose.dri.yaml    # Override para GPU Intel / AMD
```

Qué incluye la imagen:

| Componente | Detalle |
|---|---|
| Base | `osrf/ros:humble-desktop` (Ubuntu 22.04), fijada por digest |
| Simulación | Gazebo Classic 11, `gazebo_ros_pkgs`, `gazebo_ros2_control` |
| Control | `ros2_control`, `ros2_controllers` |
| Planificación | MoveIt 2, `pick_ik`, MoveIt Setup Assistant |
| Visualización | RViz2, `joint_state_publisher_gui` |
| Usuario | `ros` con el mismo UID/GID que tu usuario del host |

---

## 2. Requisitos

- **Sistema operativo:** Ubuntu 22.04 o 24.04 (probado en Ubuntu con GNOME/Wayland).
- **Espacio en disco:** ~15 GB libres (imagen + caché).
- **GPU (opcional pero recomendado):**
  - NVIDIA (RTX/GTX) → driver propietario + NVIDIA Container Toolkit.
  - Intel / AMD → drivers Mesa (vienen con Ubuntu).
- **Internet** para descargar la imagen y los paquetes.

---

## 3. Instalación en el anfitrión (host)

Todos los pasos de esta sección se hacen **en tu máquina**, no dentro del contenedor.

### 3.1 Herramientas básicas

```bash
sudo apt update
sudo apt install -y git curl ca-certificates x11-xserver-utils
```

`x11-xserver-utils` proporciona `xhost`, necesario para abrir ventanas gráficas desde el contenedor.

### 3.2 Docker Engine + Docker Compose

Si ya tienes Docker y `docker compose version` funciona, salta al punto 3.3.

```bash
# Repositorio oficial de Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalación
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
```

Permite usar Docker sin `sudo`:

```bash
sudo usermod -aG docker $USER
```

**Cierra sesión y vuelve a entrar** (o reinicia) para que el cambio aplique. Verifica:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

### 3.3 Driver de NVIDIA (solo si tienes GPU NVIDIA)

Comprueba si ya lo tienes:

```bash
nvidia-smi
```

Si muestra tu GPU, continúa con el punto 3.4. Si no, instala el driver recomendado:

```bash
sudo ubuntu-drivers devices      # muestra el driver recomendado
sudo ubuntu-drivers install      # instala el recomendado
sudo reboot
```

Si tienes **Secure Boot** activado, Ubuntu te pedirá crear una contraseña de
MOK durante la instalación; deberás confirmarla en el siguiente reinicio.

### 3.4 NVIDIA Container Toolkit (solo NVIDIA)

Permite que los contenedores accedan a la GPU.

```bash
# Repositorio oficial
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Instalación
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Registrar el runtime en Docker y reiniciar
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Verifica que Docker ve el runtime y la GPU:

```bash
docker info | grep -i runtimes          # debe incluir "nvidia"
docker run --rm --gpus all ubuntu nvidia-smi
```

Si el segundo comando muestra tu GPU, el host está listo.

### 3.5 GPU Intel / AMD

No requiere instalación extra. Comprueba que existe el dispositivo:

```bash
ls /dev/dri
```

Debe aparecer algo como `card0` y `renderD128`.

---

## 4. Clonar y configurar el proyecto

```bash
mkdir -p ~/ROBOCUP && cd ~/ROBOCUP
git clone <https://github.com/Embedar/martha_arm.git> martha_arm
cd martha_arm
```

### 4.1 Archivo `.env` (UID/GID)

Para que los archivos creados dentro del contenedor te pertenezcan a ti (y no a
root), el contenedor usa tu UID/GID. Crea `docker/.env`:

```bash
cat > docker/.env << EOF
UID=$(id -u)
GID=$(id -g)
ROS_DOMAIN_ID=0
EOF
```

Compruébalo:

```bash
cat docker/.env
```

> `docker/.env` es una configuración local de cada persona; no debe subirse al
> repositorio (añádelo a `.gitignore`).

### 4.2 Permitir ventanas gráficas

Cada vez que inicies sesión en tu equipo, ejecuta en el host:

```bash
xhost +local:docker
```

Debe responder `non-network local connections being added to access control list`.

Verifica también tu `DISPLAY`:

```bash
echo $DISPLAY
```

Normalmente es `:0` o `:1`. Si no es `:0`, expórtalo antes de levantar el
contenedor (ver sección 5).

---

## 5. Construir y levantar el contenedor

Todos los comandos se ejecutan desde la raíz del repositorio (`martha_arm/`).
Elige **una** de las tres variantes según tu hardware.

### Opción A: GPU NVIDIA

```bash
docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d --build
```

### Opción B: GPU Intel / AMD

```bash
docker compose -f docker/compose.yaml -f docker/compose.dri.yaml up -d --build
```

### Opción C: Sin GPU (render por software, lento)

```bash
MARTHA_SOFTWARE_GL=1 docker compose -f docker/compose.yaml up -d --build
```

La **primera construcción** descarga ROS 2 Humble, Gazebo y MoveIt 2 y puede
tardar entre 10 y 30 minutos según tu conexión.

Si tu `DISPLAY` no es `:0`, antepón la variable:

```bash
DISPLAY=$DISPLAY docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d --build
```

Comprueba que el contenedor está corriendo:

```bash
docker ps --filter name=martha
```

---

## 6. Verificar que todo funciona

Entra al contenedor:

```bash
docker exec -it martha bash
```

El prompt cambia a `ros@...:/ros2_ws$`. **Los siguientes comandos se ejecutan
dentro del contenedor, uno a uno:**

```bash
# 1. ROS 2 cargado
ros2 --version
echo $ROS_DISTRO            # humble

# 2. GPU (solo NVIDIA)
nvidia-smi

# 3. Renderizado: debe decir NVIDIA (o tu GPU Intel/AMD), no "llvmpipe"
glxinfo -B | grep -E "vendor|renderer"

# 4. Interfaces gráficas
rviz2
gazebo --verbose
```

Qué esperar:

| Prueba | Resultado correcto | Si falla |
|---|---|---|
| `nvidia-smi` | Muestra tu GPU | Revisar sección 3.4 |
| `glxinfo -B` | `NVIDIA ...` en vendor/renderer | `llvmpipe` = render por CPU, ver sección 10 |
| `rviz2` / `gazebo` | Se abre la ventana | Revisar `xhost` y `DISPLAY` |

Para salir del contenedor: `exit` (el contenedor sigue corriendo en segundo plano).

---

## 7. Compilar el workspace

Dentro del contenedor:

```bash
cd /ros2_ws
rosdep update
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

El contenedor incluye un alias que hace la compilación y el `source` de una vez:

```bash
cb
```

El workspace `ros2_ws/` está montado desde tu máquina, así que puedes editar el
código con tu editor favorito en el host y compilar dentro del contenedor.

---

## 8. Uso diario

| Acción | Comando (desde `martha_arm/`) |
|---|---|
| Permitir ventanas (cada sesión) | `xhost +local:docker` |
| Levantar (NVIDIA) | `docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d` |
| Entrar al contenedor | `docker exec -it martha bash` |
| Abrir otra terminal | `docker exec -it martha bash` (en otra pestaña) |
| Detener | `docker compose -f docker/compose.yaml down` |
| Reconstruir imagen | `docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d --build` |
| Recrear contenedor | añadir `--force-recreate` al `up` |
| Ver logs | `docker logs martha` |

Reemplaza `compose.nvidia.yaml` por `compose.dri.yaml` si usas Intel/AMD.

Opcional: define un alias en tu `~/.bashrc` del host para no escribir tanto:

```bash
alias martha-up='cd ~/ROBOCUP/martha_arm && xhost +local:docker && docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d'
alias martha='docker exec -it martha bash'
alias martha-down='cd ~/ROBOCUP/martha_arm && docker compose -f docker/compose.yaml down'
```

---

## 9. Variables de configuración

| Variable | Por defecto | Descripción |
|---|---|---|
| `UID` / `GID` | `1000` | UID/GID del usuario `ros` dentro del contenedor. Debe coincidir con el tuyo (`id -u`, `id -g`). Si lo cambias, reconstruye con `--build`. |
| `DISPLAY` | `:0` | Pantalla X11 donde se abren las ventanas. |
| `ROS_DOMAIN_ID` | `0` | Dominio DDS de ROS 2. Cámbialo si compartes red con otros equipos. |
| `MARTHA_SOFTWARE_GL` | `0` | `1` fuerza renderizado por software (sin GPU). |

Configuración de red y memoria: el contenedor usa `network_mode: host` e
`ipc: host`, necesarios para la comunicación DDS de ROS 2 entre procesos y con
otras máquinas de la red.

---

## 10. Solución de problemas

### `glxinfo` dice `llvmpipe` (renderiza por CPU)

Con NVIDIA:

```bash
# En el host
docker info | grep -i runtimes                 # debe incluir nvidia
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d --force-recreate
```

Si persiste, agrega en `docker/compose.nvidia.yaml`, dentro de `environment`:

```yaml
__GLX_VENDOR_LIBRARY_NAME: nvidia
```

Comprueba también que no tienes `MARTHA_SOFTWARE_GL=1` activo.

### `cannot connect to X server` / `Authorization required`

```bash
# En el host
xhost +local:docker
echo $DISPLAY
```

Si `DISPLAY` no es `:0`, levanta el contenedor con `DISPLAY=$DISPLAY docker compose ...`.

### `permission denied` al usar Docker

No estás en el grupo `docker`:

```bash
sudo usermod -aG docker $USER
```

Cierra sesión y vuelve a entrar.

### Los archivos de `ros2_ws/` quedan con dueño `root` o un UID raro

El UID/GID del contenedor no coincide con el tuyo. Revisa `docker/.env`, luego:

```bash
docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d --build --force-recreate
sudo chown -R $(id -u):$(id -g) ros2_ws
```

### Gazebo se comporta raro o falla al cargar modelos

Borra la caché de Gazebo:

```bash
docker compose -f docker/compose.yaml down
docker volume rm martha_martha_gazebo_cache
```

### `docker: command not found` dentro del contenedor

Es normal. Docker solo existe en el host. Comprueba el prompt: `ros@` es
contenedor, `lorenzo@` (tu usuario) es host.

### Los nodos de ROS 2 no se ven entre terminales

Todas las terminales deben usar el mismo `ROS_DOMAIN_ID`. Verifica:

```bash
echo $ROS_DOMAIN_ID
ros2 node list
```

### Reconstruir todo desde cero

```bash
docker compose -f docker/compose.yaml down
docker rmi martha:humble
docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml build --no-cache
docker compose -f docker/compose.yaml -f docker/compose.nvidia.yaml up -d
```

---

## Notas

- El contenedor da `sudo` sin contraseña al usuario `ros`: pensado para
  desarrollo, no para producción.
- La imagen base está fijada por digest para que todos los integrantes del
  equipo construyan exactamente el mismo entorno.
