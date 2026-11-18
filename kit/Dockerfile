ARG UBUNTU_BASE=ubuntu:24.04
FROM ${UBUNTU_BASE} AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get -o Acquire::Languages=none update --error-on=any \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl git openssh-client python3 python3-venv ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && if getent passwd 1000 >/dev/null; then \
         usermod --login lab --home /home/lab --move-home "$(getent passwd 1000 | cut -d: -f1)"; \
       else \
         if ! getent group 1000 >/dev/null; then groupadd --gid 1000 lab; fi; \
         useradd --uid 1000 --gid 1000 --no-log-init --create-home --shell /bin/bash lab; \
       fi \
    && install -d -o 1000 -g 1000 /workspace
ENV HOME=/home/lab LANG=C.UTF-8
USER 1000:1000
WORKDIR /workspace
CMD ["sleep", "infinity"]

FROM base AS sources
USER root
RUN apt-get -o Acquire::Languages=none update --error-on=any \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git-lfs \
    && rm -rf /var/lib/apt/lists/*
COPY fetch-source /usr/local/bin/fetch-source
RUN bash /usr/local/bin/fetch-source https://github.com/rt-net/mujina_ros.git \
    38ff97f12d0ef424dd7fc840d3ce7a1ebad2a49d /src/mujina_ros \
    && test "$(stat -c %s /src/mujina_ros/mujina_control/models/policy.pt)" -gt 4096
RUN bash /usr/local/bin/fetch-source https://github.com/rt-net/mujina_isaac_lab.git \
    98bf94e75ecf00c5f9d44d122fdc0f949d6b89dd /src/mujina_isaac_lab \
    && test -n "$(find /src/mujina_isaac_lab -name mujina.usd -size +1M -print -quit)"
RUN bash /usr/local/bin/fetch-source https://github.com/isaac-sim/IsaacLab.git \
    3c6e67bb5c7ada942a6d1884ab69338f57596f77 /src/IsaacLab

FROM base AS ros
USER root
RUN curl -fsSL --retry 3 -o /tmp/ros2-apt-source.deb \
       https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.3.0/ros2-apt-source_1.3.0.noble_all.deb \
    && printf '%s  /tmp/ros2-apt-source.deb\n' f31d84adf5054c7d60ded0e82c0f776a77ea33af53d08f40b9ad7c94cca55296 | sha256sum -c - \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm /tmp/ros2-apt-source.deb \
    && apt-get -o Acquire::Languages=none update --error-on=any \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       build-essential cmake git-lfs python3-colcon-common-extensions \
       ros-jazzy-ros-base ros-jazzy-joy ros-jazzy-joy-linux ros-jazzy-robot-state-publisher \
       ros-jazzy-joint-state-publisher-gui ros-jazzy-rviz2 ros-jazzy-urdfdom-py ros-jazzy-xacro \
       ros-jazzy-rosidl-default-generators ros-jazzy-rosidl-default-runtime \
       can-utils python3-bitstring python3-scipy \
       libvulkan1 libgl1 libglx0 libegl1 libgbm1 libopengl0 libglu1-mesa libgl1-mesa-dri \
       libglfw3 libxcb-xinerama0 libx11-xcb1 libxrandr2 libxcursor1 libxmu6 libxi6 \
       libxkbcommon0 libnss3 libxss1 libxtst6 libasound2t64 xvfb xauth x11-utils \
    && rm -rf /var/lib/apt/lists/*
COPY --from=sources /src/mujina_ros /opt/mujina-source/mujina_ros
COPY --from=sources /src/mujina_isaac_lab /opt/mujina-source/mujina_isaac_lab
RUN python3 -m venv --system-site-packages /opt/mujina-ros-python \
    && /opt/mujina-ros-python/bin/pip --disable-pip-version-check --no-cache-dir install \
       --index-url https://download.pytorch.org/whl/cpu torch==2.7.0 \
    && /opt/mujina-ros-python/bin/pip --disable-pip-version-check --no-cache-dir install \
       'numpy<2' mujoco==3.3.7 onnxruntime==1.23.2 \
    && source /opt/ros/jazzy/setup.bash \
    && colcon --log-base /tmp/ros-log build --base-paths /opt/mujina-source/mujina_ros \
       --build-base /tmp/ros-build --merge-install --install-base /opt/mujina-ros \
    && rm -rf /tmp/ros-log /tmp/ros-build

FROM base AS isaac
USER root
ENV PIP_DEFAULT_TIMEOUT=120 UV_PYTHON_INSTALL_DIR=/opt/mujina-python
RUN python3 -m venv /tmp/uv \
    && /tmp/uv/bin/pip --disable-pip-version-check --no-cache-dir install uv==0.9.17 \
    && /tmp/uv/bin/uv python install 3.11.14 \
    && /tmp/uv/bin/uv venv --seed --python 3.11.14 /opt/mujina-isaac \
    && rm -rf /tmp/uv
RUN /opt/mujina-isaac/bin/pip --disable-pip-version-check --no-cache-dir install \
       --index-url https://download.pytorch.org/whl/cu128 torch==2.7.0 torchvision==0.22.0 \
    && /opt/mujina-isaac/bin/pip --disable-pip-version-check --no-cache-dir install \
       --extra-index-url https://pypi.nvidia.com 'isaacsim[all,extscache]==5.1.0'
COPY --from=sources /src/IsaacLab /opt/IsaacLab
COPY --from=sources /src/mujina_isaac_lab /opt/mujina-source/mujina_isaac_lab
COPY isaac-build-constraints.txt isaac-runtime-constraints.txt /tmp/
RUN /opt/mujina-isaac/bin/pip --disable-pip-version-check --no-cache-dir install \
       --build-constraint /tmp/isaac-build-constraints.txt \
       --constraint /tmp/isaac-runtime-constraints.txt wheel \
       -e /opt/IsaacLab/source/isaaclab \
       -e /opt/IsaacLab/source/isaaclab_assets \
       -e /opt/IsaacLab/source/isaaclab_tasks \
       -e /opt/IsaacLab/source/isaaclab_mimic \
       -e '/opt/IsaacLab/source/isaaclab_rl[rsl-rl]' \
       -e /opt/mujina-source/mujina_isaac_lab/source/mujina_isaac_lab \
    && /opt/mujina-isaac/bin/pip check

FROM ros AS sim
COPY --from=isaac /opt/mujina-python /opt/mujina-python
COPY --from=isaac /opt/mujina-isaac /opt/mujina-isaac
COPY --from=isaac /opt/IsaacLab /opt/IsaacLab
COPY --chmod=0755 bin/ /usr/local/bin/
COPY preview.py /opt/mujina-source/preview.py
RUN printf '\n. /opt/ros/jazzy/setup.bash\n. /opt/mujina-ros/setup.bash\n' >> /etc/bash.bashrc
USER 1000:1000
