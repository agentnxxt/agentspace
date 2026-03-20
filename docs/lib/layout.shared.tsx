import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

// Agentspace GitHub repository
export const gitConfig = {
  user: 'spacedriveapp',
  repo: 'agentspace',
  branch: 'main',
};

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: 'Agentspace',
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
