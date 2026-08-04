import { Button, Group, ScrollArea, Stack, Text } from '@mantine/core';
import { useSetters, useStore } from '../../../../store';

interface SoundOptionsProps {
  label: string;
  sounds: string[];
  value: string | null;
  onChange: (value: string | null) => void;
}

const SoundOptions: React.FC<SoundOptionsProps> = ({ label, sounds, value, onChange }) => (
  <Stack spacing={8}>
    <Text size="sm" weight={600} color="node7Gold.2">
      {label}
    </Text>
    <ScrollArea style={{ height: 92 }} offsetScrollbars>
      <Group spacing={6}>
        <Button
          compact
          variant={!value ? 'filled' : 'outline'}
          onClick={() => onChange(null)}
        >
          None
        </Button>
        {sounds.map((sound) => (
          <Button
            key={sound}
            compact
            variant={value === sound ? 'filled' : 'outline'}
            onClick={() => onChange(sound)}
          >
            {sound}
          </Button>
        ))}
      </Group>
    </ScrollArea>
  </Stack>
);

const Sound: React.FC = () => {
  const sounds = useSetters((state) => state.sounds);
  const lockSound = useStore((state) => state.lockSound);
  const unlockSound = useStore((state) => state.unlockSound);
  const setLockSound = useSetters((setter) => setter.setLockSound);
  const setUnlockSound = useSetters((setter) => setter.setUnlockSound);

  return (
    <Stack spacing={18}>
      <SoundOptions label="Lock sound" sounds={sounds} value={lockSound} onChange={setLockSound} />
      <SoundOptions label="Unlock sound" sounds={sounds} value={unlockSound} onChange={setUnlockSound} />
    </Stack>
  );
};

export default Sound;
