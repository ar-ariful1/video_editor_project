// admin_panel/pages/index.tsx
import { useEffect } from 'react';
import { useRouter } from 'next/router';

export default function IndexPage() {
  const router = useRouter();
  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    router.replace(token ? '/dashboard' : '/login');
  }, []);
  return null;
}
