# TypeScript/CDK Specific Patterns

Language-specific risk patterns for TypeScript and AWS CDK development.

---

## TypeScript A-Class Patterns

### Non-null Assertion (`!`)

**Risk Level**: A1 (Implicit Assumption)

```typescript
// BAD - Runtime crash if null
const user = users.find(u => u.id === id)!;
const name = user.name;

// GOOD - Explicit handling
const user = users.find(u => u.id === id);
if (!user) {
    throw new UserNotFoundError(id);
}
const name = user.name;
```

### Type Assertion (`as`)

**Risk Level**: A1 (Implicit Assumption)

```typescript
// BAD - Bypasses type checking
const data = response as UserData;

// GOOD - Runtime validation
import { z } from 'zod';

const UserDataSchema = z.object({
    id: z.string(),
    name: z.string(),
});

const data = UserDataSchema.parse(response);
```

### Any Type

**Risk Level**: A1 (Implicit Assumption)

```typescript
// BAD - No type safety
function processData(data: any) {
    return data.value.nested.property;  // Can crash
}

// GOOD - Proper typing
interface Data {
    value: {
        nested: {
            property: string;
        };
    };
}

function processData(data: Data) {
    return data.value.nested.property;
}
```

### Unhandled Promise Rejection

**Risk Level**: A5 (Error Path Not First-Class)

```typescript
// BAD - Unhandled rejection
async function fetchData() {
    fetch(url).then(r => r.json());  // No catch
}

// GOOD - Handle errors
async function fetchData() {
    try {
        const response = await fetch(url);
        return await response.json();
    } catch (error) {
        logger.error('Fetch failed', { error, url });
        throw new FetchError(url, error);
    }
}
```

### Missing Null Check After Optional Chaining

**Risk Level**: A3 (Incomplete Conditional)

```typescript
// BAD - Continues with undefined
const name = user?.profile?.name;
sendEmail(name);  // name could be undefined

// GOOD - Handle undefined case
const name = user?.profile?.name;
if (!name) {
    throw new Error('User profile name is required');
}
sendEmail(name);
```

---

## CDK A-Class Patterns

### Hardcoded Account/Region

**Risk Level**: A1 (Implicit Assumption)

```typescript
// BAD - Won't work in different environments
new Stack(app, 'MyStack', {
    env: {
        account: '123456789012',
        region: 'us-east-1',
    },
});

// GOOD - Environment-agnostic or from context
new Stack(app, 'MyStack', {
    env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION,
    },
});
```

### Missing Removal Policy

**Risk Level**: A5 (Error Path Not First-Class)

```typescript
// BAD - Data loss on stack deletion
new s3.Bucket(this, 'DataBucket');

// GOOD - Explicit retention
new s3.Bucket(this, 'DataBucket', {
    removalPolicy: cdk.RemovalPolicy.RETAIN,
    autoDeleteObjects: false,
});
```

### Overly Permissive IAM

**Risk Level**: A1 (Implicit Assumption)

```typescript
// BAD - Too permissive
role.addToPolicy(new iam.PolicyStatement({
    actions: ['s3:*'],
    resources: ['*'],
}));

// GOOD - Least privilege
role.addToPolicy(new iam.PolicyStatement({
    actions: ['s3:GetObject', 's3:PutObject'],
    resources: [bucket.arnForObjects('uploads/*')],
}));
```

### Missing VPC Configuration

**Risk Level**: A4 (Complex Async)

```typescript
// BAD - Lambda in public subnet with no VPC
new lambda.Function(this, 'ApiHandler', {
    // ... no VPC config
});

// GOOD - Proper VPC placement for sensitive workloads
new lambda.Function(this, 'ApiHandler', {
    vpc,
    vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
    },
    // ...
});
```

### Secrets in Plain Text

**Risk Level**: A1 (Implicit Assumption)

```typescript
// BAD - Secret in code
new lambda.Function(this, 'Handler', {
    environment: {
        DB_PASSWORD: 'my-secret-password',
    },
});

// GOOD - Use Secrets Manager
const secret = secretsmanager.Secret.fromSecretNameV2(
    this, 'DbSecret', 'prod/db/password'
);

new lambda.Function(this, 'Handler', {
    environment: {
        DB_SECRET_ARN: secret.secretArn,
    },
});
secret.grantRead(handler);
```

---

## TypeScript B-Class Patterns

### Magic Numbers/Strings

**Risk Level**: B1 (Type Contracts)

```typescript
// BAD
if (status === 'active') { ... }
const timeout = 30000;

// GOOD
enum UserStatus {
    Active = 'active',
    Inactive = 'inactive',
}

const TIMEOUT_MS = 30000;

if (status === UserStatus.Active) { ... }
```

### Missing Interface/Type

**Risk Level**: B2 (Serialization)

```typescript
// BAD - Inline object type
function createUser(data: { name: string; age: number }) {
    // ...
}

// GOOD - Explicit interface
interface CreateUserInput {
    name: string;
    age: number;
}

function createUser(data: CreateUserInput) {
    // ...
}
```

### Console.log in Production Code

**Risk Level**: B5 (Observability)

```typescript
// BAD
console.log('User created:', userId);

// GOOD
import { Logger } from '@aws-lambda-powertools/logger';
const logger = new Logger();

logger.info('User created', { userId });
```

### Missing Error Type

**Risk Level**: B5 (Observability)

```typescript
// BAD - Generic error
throw new Error('User not found');

// GOOD - Custom error class
class UserNotFoundError extends Error {
    constructor(public readonly userId: string) {
        super(`User not found: ${userId}`);
        this.name = 'UserNotFoundError';
    }
}

throw new UserNotFoundError(userId);
```

---

## CDK B-Class Patterns

### Missing Tags

**Risk Level**: B5 (Observability)

```typescript
// BAD - No tags
new s3.Bucket(this, 'DataBucket');

// GOOD - Tagged for cost tracking
const bucket = new s3.Bucket(this, 'DataBucket');
cdk.Tags.of(bucket).add('Project', 'MyProject');
cdk.Tags.of(bucket).add('Environment', 'Production');
```

### Missing Description

**Risk Level**: B4 (Maintainability)

```typescript
// BAD - No description
new lambda.Function(this, 'Handler', {
    // ...
});

// GOOD - Documented
new lambda.Function(this, 'Handler', {
    description: 'Handles user registration webhook events',
    // ...
});
```

### Hardcoded Timeout/Memory

**Risk Level**: B1 (Type Contracts)

```typescript
// BAD - Magic numbers
new lambda.Function(this, 'Handler', {
    timeout: cdk.Duration.seconds(30),
    memorySize: 256,
});

// GOOD - Named constants
const LAMBDA_TIMEOUT = cdk.Duration.seconds(30);
const LAMBDA_MEMORY_MB = 256;

new lambda.Function(this, 'Handler', {
    timeout: LAMBDA_TIMEOUT,
    memorySize: LAMBDA_MEMORY_MB,
});
```

### Missing Alarms

**Risk Level**: B5 (Observability)

```typescript
// BAD - No monitoring
const fn = new lambda.Function(this, 'Handler', { ... });

// GOOD - With alarms
const fn = new lambda.Function(this, 'Handler', { ... });

new cloudwatch.Alarm(this, 'ErrorAlarm', {
    metric: fn.metricErrors(),
    threshold: 1,
    evaluationPeriods: 1,
    alarmDescription: 'Lambda function errors',
});
```

---

## Lambda Patterns

### Missing Dead Letter Queue

```typescript
// BAD - Failed events lost
new lambda.Function(this, 'Handler', {
    // ...
});

// GOOD - Failed events captured
const dlq = new sqs.Queue(this, 'DLQ');

new lambda.Function(this, 'Handler', {
    deadLetterQueue: dlq,
    retryAttempts: 2,
});
```

### Missing Reserved Concurrency

```typescript
// BAD - Can overwhelm downstream services
new lambda.Function(this, 'Handler', {
    // ...
});

// GOOD - Controlled concurrency
new lambda.Function(this, 'Handler', {
    reservedConcurrentExecutions: 10,
});
```

---

## Detection Keywords Summary

| Pattern | Keywords | Risk |
|---------|----------|------|
| Non-null assertion | `!` after expression | A1 |
| Type assertion | `as SomeType` | A1 |
| Any type | `: any` | A1 |
| Unhandled promise | `.then(` without `.catch(` | A5 |
| Hardcoded credentials | `password:`, `secret:` string literal | A1 |
| Console.log | `console.log(` | B5 |
| Magic number | numeric literal in config | B1 |
| Missing tags | CDK construct without `Tags.of` | B5 |
| s3:* permission | `actions: ['s3:*']` | A1 |
