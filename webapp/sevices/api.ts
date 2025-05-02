// services/api.ts
import { Performer, getPerformersByAuditionId } from '@/utils/mocks/performers';

// Mock API service to simulate fetching performers data
export const fetchPerformersByAuditionId = async (auditionId: string): Promise<Performer[]> => {
  // Simulate API request delay
  return new Promise((resolve) => {
    setTimeout(() => {
      const performers = getPerformersByAuditionId(auditionId);
      resolve(performers);
    }, 500);
  });
};