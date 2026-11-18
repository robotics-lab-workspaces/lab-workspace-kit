"""Replay RT's locally retrieved MuJina policy in one Isaac Lab environment."""
import argparse
from pathlib import Path
import time

from isaaclab.app import AppLauncher


def replay(app, args):
    import gymnasium as gym
    import mujina_isaac_lab.tasks  # Registers the MuJina environment.
    import torch
    from isaaclab_tasks.utils import parse_env_cfg

    task = "Isaac-Velocity-Rough-Mujina-Play-v0"
    config = parse_env_cfg(task, device=args.device, num_envs=1)
    config.seed = 42
    command = config.commands.base_velocity
    command.heading_command = False
    command.rel_standing_envs = 0.0
    command.ranges.lin_vel_x = (0.5, 0.5)
    command.ranges.lin_vel_y = (0.0, 0.0)
    command.ranges.ang_vel_z = (0.0, 0.0)
    config.viewer.origin_type = "asset_root"
    config.viewer.asset_name = "robot"
    config.viewer.eye = (2.1, 1.7, 1.4)
    config.viewer.lookat = (0.0, 0.0, 0.25)

    env = gym.make(task, cfg=config)
    try:
        robot = env.unwrapped.scene["robot"]
        path = Path("/opt/mujina-source/mujina_ros/mujina_control/models/policy.pt")
        policy = torch.jit.load(str(path), map_location=env.unwrapped.device).eval()
        observation, _ = env.reset()
        origin = robot.data.root_pos_w[0, :2].clone()
        steps = 0
        with torch.inference_mode():
            while app.is_running() and (not args.steps or steps < args.steps):
                before = time.monotonic()
                observation, _, _, _, _ = env.step(policy(observation["policy"]))
                steps += 1
                if steps == 1:
                    print("MuJina policy replay started", flush=True)
                remaining = env.unwrapped.step_dt - (time.monotonic() - before)
                if not args.headless and remaining > 0:
                    time.sleep(remaining)
        if args.steps:
            distance = (robot.data.root_pos_w[0, :2] - origin).norm().item()
            print(f"Replay: {steps} steps, {distance:.3f} m", flush=True)
    finally:
        env.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--steps", type=int, default=0, help="Zero runs until closed.")
    AppLauncher.add_app_launcher_args(parser)
    args = parser.parse_args()
    app = AppLauncher(args).app
    try:
        replay(app, args)
    finally:
        app.close()
