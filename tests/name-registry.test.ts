import { describe, it, beforeEach, expect } from 'vitest';

// Mocking the Name Registry contract for testing purposes
const mockNameRegistry = {
  state: {
    names: {} as Record<string, string>, // Maps names to owners
  },
  claimName: (name: string, caller: string) => {
    if (mockNameRegistry.state.names[name]) {
      return { error: 100 }; // Name already claimed
    }
    mockNameRegistry.state.names[name] = caller;
    return { value: true };
  },
  getOwner: (name: string) => {
    return mockNameRegistry.state.names[name] || null;
  },
};

describe('Name Registry Contract', () => {
  let user1: string, user2: string;

  beforeEach(() => {
    // Initialize mock state and user principals
    user1 = 'ST1234...';
    user2 = 'ST5678...';

    mockNameRegistry.state = {
      names: {},
    };
  });

  it('should allow a user to claim a unique name', () => {
    const result = mockNameRegistry.claimName('unique-name', user1);
    expect(result).toEqual({ value: true });
    expect(mockNameRegistry.state.names['unique-name']).toBe(user1);
  });

  it('should prevent claiming an already claimed name', () => {
    mockNameRegistry.claimName('duplicate-name', user1);
    const result = mockNameRegistry.claimName('duplicate-name', user2);
    expect(result).toEqual({ error: 100 });
    expect(mockNameRegistry.state.names['duplicate-name']).toBe(user1);
  });

  it('should retrieve the correct owner for a claimed name', () => {
    mockNameRegistry.claimName('test-name', user1);
    const owner = mockNameRegistry.getOwner('test-name');
    expect(owner).toBe(user1);
  });

  it('should return null for an unclaimed name', () => {
    const owner = mockNameRegistry.getOwner('unclaimed-name');
    expect(owner).toBeNull();
  });
});
