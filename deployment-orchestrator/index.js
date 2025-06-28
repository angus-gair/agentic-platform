#!/usr/bin/env node

import { Command } from 'commander';
import { execa } from 'execa';
import yaml from 'js-yaml';
import fs from 'fs/promises';
import path from 'path';

const program = new Command();

const fetchSecrets = async (serviceName) => {
  console.log(`Fetching secrets for ${serviceName}...`);
  // In a real scenario, this would use execa to call the Bitwarden CLI (`bw`).
  // For now, we'll simulate it and return mock data.
  // Example: const { stdout } = await execa('bw', ['get', 'item', serviceName]);
  await new Promise(resolve => setTimeout(resolve, 500)); // Simulate network delay
  
  const mockSecrets = {
    "API_KEY": "mock-api-key-for-testing",
    "DATABASE_URL": `postgres://user:pass@db.host:5432/${serviceName}`
  };

  console.log('Successfully fetched secrets.');
  return mockSecrets;
};

const generateDockerCompose = (service, secrets) => {
  console.log(`\nGenerating docker-compose for ${service.name}...`);

  const composeConfig = {
    version: '3.8',
    services: {
      [service.name]: {
        image: `your-org/${service.name}:latest`, // Placeholder image name
        container_name: service.name,
        restart: 'always',
        ports: [`${service.port}:${service.port}`],
        environment: secrets,
      },
    },
  };

  const yamlString = yaml.dump(composeConfig);
  console.log('Generated docker-compose.yml:');
  console.log(yamlString);
  return yamlString;
};

const deployViaSsh = async (service, dockerComposeYaml) => {
  console.log(`\nDeploying ${service.name} to ${service.host} via SSH...`);
  const sshTarget = `admin@${service.host}`; // Using the sudo user from your readme
  const deployDir = `/opt/deployments/${service.name}`;
  const composePath = `${deployDir}/docker-compose.yml`;

  // This is a simulation. In a real scenario, we would use execa to run these commands.
  console.log('--- SIMULATING REMOTE EXECUTION ---');
  console.log(`1. Ensure deployment directory exists:`);
  console.log(`$ ssh ${sshTarget} "mkdir -p ${deployDir}"`);

  console.log(`\n2. Write docker-compose.yml to remote server:`);
  // In a real implementation, we'd pipe the content to the ssh command.
  console.log(`$ echo "${dockerComposeYaml.replace(/"/g, '\\"')}" | ssh ${sshTarget} "cat > ${composePath}"`);

  console.log(`\n3. Pull latest image and restart service:`);
  console.log(`$ ssh ${sshTarget} "cd ${deployDir} && docker-compose pull && docker-compose up -d"`);
  console.log('--- END SIMULATION ---');

  await new Promise(resolve => setTimeout(resolve, 500)); // Simulate network delay
  console.log(`\nSuccessfully deployed ${service.name}.`);
};

program
  .name('deploy-cli')
  .description('A CLI tool to orchestrate deployments.')
  .version('1.0.0');

program
  .command('deploy')
  .description('Deploy a service based on the master configuration.')
  .argument('<service-name>', 'The name of the service to deploy')
  .option('-c, --config <path>', 'Path to the master deployment config file', 'deployments.yml')
  .action(async (serviceName, options) => {
    console.log(`Starting deployment for service: ${serviceName}`);
    
    try {
      const configFile = await fs.readFile(path.resolve(options.config), 'utf8');
      const config = yaml.load(configFile);

      const service = config.services.find(s => s.name === serviceName);

      if (!service) {
        console.error(`Error: Service "${serviceName}" not found in ${options.config}`);
        process.exit(1);
      }

      console.log('Found service configuration:');
      console.log(service);

      let secrets = {};
      if (service.requires_secrets) {
        secrets = await fetchSecrets(service.name);
        console.log('Secrets to be injected:', secrets);
      }

      if (service.type === 'platform') {
        console.log(`\nDeploying platform: ${service.name}`);
        // In a real scenario, we would implement the logic to clone the repo,
        // create the .env file from secrets, and run docker-compose.
        console.log('--- SIMULATING PLATFORM DEPLOYMENT ---');
        console.log(`1. Clone repository: git clone ${service.repository}`);
        console.log(`2. Create .env file from fetched secrets.`);
        console.log(`3. Run docker-compose: cd ${service.name} && docker-compose -f ${service.compose_file} up -d --build`);
        console.log('--- END SIMULATION ---');
        console.log(`\nSuccessfully deployed platform ${service.name}.`);
      } else {
        // Default to 'service' type deployment
        const dockerComposeYaml = generateDockerCompose(service, secrets);
        await deployViaSsh(service, dockerComposeYaml);
      }

    } catch (error) {
      console.error(`Error reading or parsing config file: ${options.config}`);
      console.error(error.message);
      process.exit(1);
    }
  });

program.parse(process.argv);