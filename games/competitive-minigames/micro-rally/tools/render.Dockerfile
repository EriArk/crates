FROM traineros-golf-backend-ci:20261025
RUN apt-get update && apt-get install -y --no-install-recommends xvfb xauth libgl1-mesa-dri libglx-mesa0 libegl1 mesa-vulkan-drivers && rm -rf /var/lib/apt/lists/*
