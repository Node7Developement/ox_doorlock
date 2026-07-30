import { Button, Group, Text } from '@mantine/core';
import { TbSettings, TbTrash } from 'react-icons/tb';
import { HiOutlineClipboardCopy } from 'react-icons/all';
import { GiTeleport } from 'react-icons/gi';
import { DoorColumn } from '../../../store/doors';
import { useNavigate } from 'react-router-dom';
import { useStore } from '../../../store';
import { convertData } from '../../../utils/convertData';
import { useClipboard } from '../../../store/clipboard';
import { fetchNui } from '../../../utils/fetchNui';
import { openConfirmModal } from '@mantine/modals';
import { CellContext } from '@tanstack/react-table';
import { useVisibility } from '../../../store/visibility';

const ActionsMenu: React.FC<{ data: CellContext<DoorColumn, unknown> }> = ({ data }) => {
  const navigate = useNavigate();
  const setClipboard = useClipboard((state) => state.setClipboard);
  const setVisible = useVisibility((state) => state.setVisible);

  return (
    <Group spacing={6} noWrap position="right">
      <Button
        compact
        size="xs"
        variant="outline"
        leftIcon={<TbSettings size={14} />}
        onClick={() => {
          useStore.setState(convertData(data.row.original), true);
          navigate('/settings/general');
        }}
      >
        Edit
      </Button>

      <Button
        compact
        size="xs"
        variant="outline"
        leftIcon={<HiOutlineClipboardCopy size={14} />}
        onClick={() => {
          setClipboard(convertData(data.row.original));
          fetchNui('notify', 'Settings copied');
        }}
      >
        Copy
      </Button>

      <Button
        compact
        size="xs"
        variant="outline"
        leftIcon={<GiTeleport size={14} />}
        onClick={() => {
          setVisible(false);
          fetchNui('teleportToDoor', data.row.getValue('id'));
        }}
      >
        Go
      </Button>

      <Button
        compact
        size="xs"
        color="red"
        variant="outline"
        leftIcon={<TbTrash size={14} />}
        onClick={() =>
          openConfirmModal({
            title: 'Confirm deletion',
            centered: true,
            withCloseButton: false,
            children: (
              <Text>
                Are you sure you want to delete
                <Text component="span" weight={700}>{` ${data.row.getValue('name')}`}</Text>?
              </Text>
            ),
            labels: { confirm: 'Confirm', cancel: 'Cancel' },
            confirmProps: { color: 'red' },
            onConfirm: () => fetchNui('deleteDoor', data.row.getValue('id')),
          })
        }
      >
        Delete
      </Button>
    </Group>
  );
};

export default ActionsMenu;
