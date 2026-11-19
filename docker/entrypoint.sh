
#!/usr/bin/env bash

# Detener la ejecucion si ocurre algun error
set -e

# Cargar ROS 2 Humble
source /opt/ros/humble/setup.bash

# Cargar Gazebo solamente si su script existe
if [ -f /usr/share/gazebo/setup.sh ]; then
    source /usr/share/gazebo/setup.sh
fi

# Cargar el workspace de MARTHA si ya fue compilado
if [ -f /ros2_ws/install/setup.bash ]; then
    source /ros2_ws/install/setup.bash
fi

# Ejecutar el comando principal del contenedor
exec "$@"

