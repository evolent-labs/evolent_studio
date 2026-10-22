import './styles/fonts.css';
import './styles/base.css';
import './styles/layout.css';
import './styles/controls.css';
import { mount } from 'svelte';
import App from './App.svelte';
import { isNuiMessage, receive } from './stores';
import { listenForJobs } from './lib/photos';

listenForJobs();
addEventListener('message', (event) => {
  if (isNuiMessage(event.data)) receive(event.data);
});

mount(App, { target: document.getElementById('app')! });
