"""Run a short zero-action MuJina simulation."""
import argparse

from isaaclab.app import AppLauncher


def preview(app, args):
    import gymnasium as gym
    import mujina_isaac_lab.tasks  # Registers the MuJina environment.
    import torch
    from isaaclab_tasks.utils import parse_env_cfg

    task = "Isaac-Velocity-Rough-Mujina-v0"
    config = parse_env_cfg(task, device=args.device, num_envs=1)
    env = gym.make(task, cfg=config)
    try:
        env.reset()
        action = torch.zeros(env.action_space.shape, device=env.unwrapped.device)
        step = 0
        while app.is_running() and (not args.steps or step < args.steps):
            env.step(action)
            step += 1
            if step == 1:
                print("MuJina preview ready", flush=True)
    finally:
        env.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--steps", type=int, default=0, help="Zero runs until closed.")
    AppLauncher.add_app_launcher_args(parser)
    options = parser.parse_args()
    app = AppLauncher(options).app
    try:
        preview(app, options)
    finally:
        app.close()
