import { Performer, getPerformersByAuditionId } from '@/utils/mocks/performers';

export const fetchPerformersByAuditionId = async (auditionId: string): Promise<Performer[]> => {
  return new Promise((resolve) => {
    setTimeout(() => {
      const performers = getPerformersByAuditionId(auditionId);
      resolve(performers);
    }, 500);
  });
};