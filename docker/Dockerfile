
# ==========================================================
# MARTHA - ROS 2 Humble + Gazebo Classic 11 + MoveIt 2
# Base: Ubuntu 22.04 (Jammy)
# ==========================================================

# Misma imagen base fijada por el proyecto MILO
FROM osrf/ros:humble-desktop@sha256:fb07245b32187d74350be25323d8ad2f8ca5c25c325759911a1eff2267a49c1e

# ----------------------------------------------------------
# 1. Configuracion del usuario
# ----------------------------------------------------------

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------------------------------------
# 2. Herramientas ROS 2 y Gazebo
# ----------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-xacro \
    ros-humble-robot-state-publisher \
    ros-humble-joint-state-publisher \
    ros-humble-joint-state-publisher-gui \
    ros-humble-rviz2 \
    ros-humble-ros2-control \
    ros-humble-ros2-controllers \
    ros-humble-gazebo-ros2-control \
    python3-colcon-common-extensions \
    mesa-utils \
    git \
    sudo \
    bash-completion \
    nano \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------
# 3. MoveIt 2
# ----------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-moveit \
    ros-humble-moveit-ros-perception \
    ros-humble-moveit-setup-assistant \
    ros-humble-moveit-configs-utils \
    ros-humble-pick-ik \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------
# 4. Crear usuario con los mismos UID y GID del anfitrion
# ----------------------------------------------------------

RUN if getent group ${USER_GID} >/dev/null; then \
        groupmod -n ${USERNAME} $(getent group ${USER_GID} | cut -d: -f1); \
    else \
        groupadd --gid ${USER_GID} ${USERNAME}; \
    fi \
    && if getent passwd ${USER_UID} >/dev/null; then \
        usermod -l ${USERNAME} -d /home/${USERNAME} -m \
        $(getent passwd ${USER_UID} | cut -d: -f1); \
    else \
        useradd --uid ${USER_UID} --gid ${USER_GID} \
        -m -s /bin/bash ${USERNAME}; \
    fi \
    && usermod -aG video,sudo,dialout ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" \
    > /etc/sudoers.d/${USERNAME}

# ----------------------------------------------------------
# 5. Configurar el punto de entrada
# ----------------------------------------------------------

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# ----------------------------------------------------------
# 6. Entorno de trabajo
# ----------------------------------------------------------

USER ${USERNAME}

WORKDIR /ros2_ws

RUN mkdir -p ~/.gazebo \
    && touch ~/.sudo_as_admin_successful \
    && echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc \
    && echo 'source /usr/share/gazebo/setup.sh' >> ~/.bashrc \
    && echo '[ -f /ros2_ws/install/setup.bash ] && source /ros2_ws/install/setup.bash' >> ~/.bashrc \
    && echo "alias cb='cd /ros2_ws && colcon build --symlink-install && source install/setup.bash'" >> ~/.bashrc

# ----------------------------------------------------------
# 7. Arranque
# ----------------------------------------------------------

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

CMD ["sleep", "infinity"]
