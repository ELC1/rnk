/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    API_SECRET: process.env.API_SECRET,
    SERVER_HOST: process.env.SERVER_HOST || "127.0.0.1",
    SERVER_PORT: process.env.SERVER_PORT || "27015",
  },
}

module.exports = nextConfig
