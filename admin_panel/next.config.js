/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    domains: ['cdn.videoeditorpro.app', 'storage.googleapis.com', 's3.amazonaws.com'],
  },
  async rewrites() {
    return [
      {
        source: '/api/admin/:path*',
        destination: `${process.env.ADMIN_API_URL || 'http://localhost:3001/api'}/:path*`,
      },
    ];
  },
  env: {
    ADMIN_PATH: process.env.ADMIN_PATH || 'mgmt-changeme',
  },
};

module.exports = nextConfig;
