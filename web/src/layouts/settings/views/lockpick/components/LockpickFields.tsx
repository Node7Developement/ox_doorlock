import { useSetters, useStore } from '../../../../../store';
import { ActionIcon, Group, Modal, Paper, Text, Tooltip } from '@mantine/core';
import { useState } from 'react';
import { TbSettings, TbTrash } from 'react-icons/tb';
import DifficultyModal from '../../characters/components/DifficultyModal';

const selectData: { label: string; value: string }[] = [
  { label: 'Easy', value: 'easy' },
  { label: 'Medium', value: 'medium' },
  { label: 'Hard', value: 'hard' },
  { label: 'Custom', value: 'custom' },
];

const LockpickFields: React.FC = () => {
  const lockpickFields = useStore((state) => state.lockpickDifficulty);
  const setLockpickFields = useSetters((setter) => setter.setLockpickDifficulty);
  const [modal, setModal] = useState<{ opened: boolean; index: number }>({ opened: false, index: 0 });

  const handleRowDelete = (index: number) => {
    setLockpickFields((prevState) => prevState.filter((obj, indx) => indx !== index));
  };

  return (
    <>
      {lockpickFields.map((field, index) => {
        const value = typeof field === 'string' ? field : 'custom';
        const label = selectData.find((option) => option.value === value)?.label || 'Custom';
        const detail = typeof field === 'object' ? `Area ${field.areaSize} · Speed ${field.speedMultiplier}` : 'Preset difficulty';

        return (
          <Group
            key={`${typeof field === 'string' ? field : field.areaSize}-${index}`}
            sx={{ width: '100%' }}
            spacing={10}
            mt={index === 0 ? undefined : 12}
            noWrap
          >
            <Paper
              withBorder
              p="sm"
              sx={(theme) => ({
                flex: 1,
                backgroundColor: '#0a0907',
                borderColor: 'rgba(184, 146, 41, 0.45)',
              })}
            >
              <Text weight={600} color="node7Gold.2">{label}</Text>
              <Text size="xs" color="dimmed">{detail}</Text>
            </Paper>
            <Tooltip label="Edit option">
              <ActionIcon variant="outline" onClick={() => setModal({ opened: true, index })}>
                <TbSettings size={20} />
              </ActionIcon>
            </Tooltip>
            <Tooltip label="Delete option">
              <ActionIcon color="red" variant="outline" onClick={() => handleRowDelete(index)}>
                <TbTrash size={20} />
              </ActionIcon>
            </Tooltip>
          </Group>
        );
      })}
      <Modal
        opened={modal.opened}
        onClose={() => setModal({ ...modal, opened: false })}
        transition="fade"
        title="Lockpick difficulty"
        centered
        size="xs"
        withCloseButton={false}
      >
        <DifficultyModal selectData={selectData} setModal={setModal} modal={modal} />
      </Modal>
    </>
  );
};

export default LockpickFields;
