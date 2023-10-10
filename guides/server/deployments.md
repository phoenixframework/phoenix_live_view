# Deployments

One of the questions that arise from LiveView stateful model is what considerations are necessary when deploying a new version of LiveView.

First off, whenever LiveView disconnects, it will automatically attempt to reconnect to the server using exponential back-off. This means it will try immediately, then wait 2s and try again, then 5s and so on. If you are deploying, this typically means the next reconnection will immediately succeed and your load balancer will automatically redirect to the new servers.

However, your LiveView _may_ still have state that will be lost in this transition. How to deal with it? The good news is that there are a series of practices you can follow that will not only help with deployments but it will improve your application in general.

1. Keep state in the query parameters when appropriate. For example, if your application has tabs and the user clicked a tab, instead of using `phx-click` and `c:Phoenix.LiveView.handle_event/3` to manage it, you should implement it using `<.link patch={...}>` passing the tab name as parameter. You will then receive the new tab name `c:Phoenix.LiveView.handle_params/3` which will set the relevant assign to choose which tab to display. You can even define specific URLs for each tab in your application router. By doing this, you will reduce the amount of server state, make tab navigation sharable via links, improving search engine indexing, and more.

2. Consider storing other relevant state in the database. For example, if you are building a chat app and you want to store which messages have been read, you can store so in the database. Once the page is loaded, you retrieve the index of the last read message. This makes the application more robust, allow data to be synchronized across devices, etc.

3. If your application uses forms (which is most likely true), keep in mind that Phoenix perform automatic form recovery: in case of disconnections, Phoenix will collect the form data and resubmit it on reconnection. This mechanism works out of the box for most forms but you may want to customize it or test it for your most complex forms. See the relevant section [in the "Form bindings" document](../client/form-bindings.md) to learn more.

The idea is that: if you follow the practices above, most of your state is already handled within your app and therefore deployments should not bring additional concerns. Not only that, it will bring overall benefits to your app such as indexing, link sharing, device sharing, and so on.

If you really have complex state that cannot be immediately handled, then you may need to resort to special strategies. This may be persisting "old" state to Redis/S3/Database and loading the new state on the new connections. Or you may take special care when migrating connections (for example, if you are building a game, you may want to wait for on-going sessions to finish before turning down the old server while routing new sessions to the new ones). Such cases will depend on your requirements (and they would likely exist regardless of which application stack you are using).
