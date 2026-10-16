# OpenUI Lang Schema JSON

MoonBit 从这份 JSON 建立组件定义表。它和 `@openuidev/lang-core` 的 `library.toJSONSchema()` 使用同一组字段。属性的书写顺序就是 OpenUI Lang 位置参数的顺序。

## 文档

| 字段 | 含义 |
| --- | --- |
| `properties` | 组件名。有这个对象时，只有这里列出的名字是组件，顺序即组件表顺序。值通常是 `{ "$ref": "#/$defs/组件名" }`。 |
| `$defs` | 组件 schema，键是组件名。 |
| `$defs.<Name>.properties` | 该组件的参数。键的书写顺序是位置参数顺序。 |
| `$defs.<Name>.required` | 必填参数名，必须出现在 `properties` 里。 |
| `functions` | 库函数。每个值要有 `params`，`params` 的形状和组件 schema 相同。 |
| `actions` | 自定义 action。形状和 `functions` 相同。 |
| `description` | 说明，编译定义表时忽略。 |

没有 `properties` 时，`$defs` 里除 action 数据形状以外的项都是组件。这些名字固定跳过：`ActionExpression`、`OpenUrl`、`ToAssistant`，再加上 `actions` 的键。

## 参数 schema

每个参数是一个 JSON Schema 对象。类型按下面的优先级读取：

| 字段 | 定义表中的类型 |
| --- | --- |
| `$ref` | `#/$defs/` 后面的名字 |
| `enum` | 非空数组，元素按 JSON 字面量保存 |
| `const` | 单个字面量 |
| `anyOf` / `oneOf` / `allOf` | 子 schema 的并集，只取第一个出现的关键字 |
| `type` | `string`、`number`、`integer`、`boolean`、`object`、`array`、`null`。`integer` 记为 `number`。数组表示并集。 |
| 都没有 | 任意值 |

`default`、`items`、`additionalProperties` 留给后续校验，编译定义表时不改变参数顺序。

## 错误

缺字段和未知类型会记入 `errors`，不会悄悄丢掉。参数位置仍然保留。

- `type` 不在已知列表里：`unknown type "..."`
- `required` 里的名字不在 `properties` 里：`"<name>" is not a property`
- `properties`、`required`、`$defs`、`functions`、`actions` 的形状不对
- 函数或 action 缺少 `params`
- `properties` 点名的组件在 `$defs` 里不存在
- 文档不是 JSON 对象，或 JSON 无法解析
