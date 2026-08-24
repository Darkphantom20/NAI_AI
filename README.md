# NAI Assistant

NAI can be attached to another system through the global `window.NAI` API.

## Add system knowledge

Run this after `javascript/script.js` has loaded:

```html
<script>
  NAI.attach({
    name: 'Inventory System',
    knowledge: [
      {
        keywords: ['stock', 'inventory'],
        response: 'I can help you check inventory and stock levels.'
      },
      {
        keywords: ['warehouse'],
        response: 'The warehouse dashboard is available in the Operations section.'
      }
    ],
    getContext: () => ({
      currentUser: 'operator-42',
      selectedWarehouse: 'north'
    })
  });
</script>
```

## Connect a system response handler

Use `respond` when the attached system has its own API or assistant logic. It may be asynchronous. Return a string to handle the message; return an empty value to use NAI's knowledge fallback.

```html
<script>
  NAI.configure({
    name: 'Support Portal',
    respond: async ({ message, system, context }) => {
      const result = await fetch('/api/assistant', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message, system, context })
      });

      const data = await result.json();
      return data.reply;
    }
  });
</script>
```

Available methods:

- `NAI.attach(options)` configures the attached system.
- `NAI.configure(options)` is an alias for `attach`.
- `NAI.addKnowledge(entries)` adds more knowledge entries.
- `NAI.getSystem()` returns the current system name and knowledge entries.
