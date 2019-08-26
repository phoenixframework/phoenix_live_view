## 0.1.1-dev

### Enhancements
  - Use optimized insertAdjacentHTML for faster append/prepend and proper css animation handling 

## 0.1.0 (2019-08-25)

### Enhancements
  - The LiveView `handle_in/3` callback now receives a map of metadata about the client event
  - For `phx-change` events, `handle_in/3` now receives a `"_target"` param representing the keyspace
    of the form input name which triggered the change
  - Multiple values may be provided for any phx binding, using the `phx-value-` prefix, such as `phx-value-myval1`, `phx-value-myval2`, etc

