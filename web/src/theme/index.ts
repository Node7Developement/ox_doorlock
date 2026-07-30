import { MantineThemeOverride } from '@mantine/core';

export const customTheme: MantineThemeOverride = {
  colorScheme: 'dark',
  primaryColor: 'node7Gold',
  primaryShade: 6,
  fontFamily: 'Georgia, Times New Roman, serif',
  headings: {
    fontFamily: 'Georgia, Times New Roman, serif',
    fontWeight: 600,
  },
  colors: {
    node7Gold: [
      '#fff8dc',
      '#f8e9b0',
      '#ead27a',
      '#dabb48',
      '#c9a434',
      '#b89229',
      '#a77f20',
      '#846319',
      '#614713',
      '#3d2c0c',
    ],
  },
  black: '#080706',
  components: {
    Tooltip: {
      defaultProps: {
        transition: 'pop',
        color: 'dark.8',
      },
    },
    Button: {
      defaultProps: {
        color: 'node7Gold',
      },
      styles: (theme) => ({
        root: {
          borderColor: theme.colors.node7Gold[7],
          letterSpacing: '0.04em',
        },
      }),
    },
    ActionIcon: {
      defaultProps: {
        color: 'node7Gold',
      },
    },
    Modal: {
      styles: (theme) => ({
        modal: {
          background: 'linear-gradient(180deg, #15120d 0%, #0b0907 100%)',
          border: `1px solid ${theme.colors.node7Gold[7]}`,
          boxShadow: '0 18px 55px rgba(0, 0, 0, 0.75)',
        },
        header: {
          backgroundColor: 'transparent',
          borderBottom: `1px solid rgba(184, 146, 41, 0.35)`,
        },
        title: {
          color: theme.colors.node7Gold[2],
          letterSpacing: '0.05em',
        },
      }),
    },
    TextInput: {
      styles: (theme) => ({
        input: {
          backgroundColor: '#0a0907',
          borderColor: 'rgba(184, 146, 41, 0.48)',
          color: '#f1e4bd',
          '&:focus': { borderColor: theme.colors.node7Gold[5] },
        },
        label: { color: '#d9c78f' },
      }),
    },
    NumberInput: {
      styles: (theme) => ({
        input: {
          backgroundColor: '#0a0907',
          borderColor: 'rgba(184, 146, 41, 0.48)',
          color: '#f1e4bd',
          '&:focus': { borderColor: theme.colors.node7Gold[5] },
        },
        label: { color: '#d9c78f' },
        description: { color: '#8f856d' },
      }),
    },
    Switch: {
      defaultProps: { color: 'node7Gold' },
    },
    Pagination: {
      defaultProps: { color: 'node7Gold' },
    },
  },
};
