<script>
  export let user;
</script>

<h1>Hello {user.email}</h1>
<input type="text" bind:value={user.email} placeholder="Enter your name" />

<style>
  h1 {
    font-size: 45px;
    padding: 1.5rem;
  }

  input {
    padding: 1rem;
    border-radius: 0.5rem;
    background-color: rgb(240, 240, 240);
    color: rgb(63, 63, 63);
  }
</style>
