/**
 * 用户实体类
 */
export class User {
  uid: string = '';
  username: string = '';
  nickname: string = '';
  avatar: string = '';
  signature: string = '';
  posts: number = 0;
  reputation: number = 0;
  groupId: string = '';
  groupName: string = '';
  memberDays: number = 0;
  lastVisit: string = '';
  isActive: boolean = false;

  constructor() {}

  isLoggedIn(): boolean {
    return this.uid !== '' && this.uid !== '0';
  }

  getDisplayName(): string {
    if (this.nickname) return this.nickname;
    if (this.username) return this.username;
    return this.uid;
  }
}
