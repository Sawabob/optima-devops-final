'use strict';

const storageKey = 'optima-study-board-v1';
const form = document.querySelector('#entry-form');
const tasksList = document.querySelector('#tasks');
const summary = document.querySelector('#summary');
const empty = document.querySelector('#empty');
const warning = document.querySelector('#save-warning');
const dateFormat = new Intl.DateTimeFormat('uk-UA', { dateStyle: 'medium', timeZone: 'UTC' });

function loadTasks() {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey) || '[]');
    if (!Array.isArray(saved)) return [];
    return saved.filter(item => item && typeof item.id === 'string' &&
      typeof item.title === 'string' && typeof item.date === 'string' &&
      /^\d{4}-\d{2}-\d{2}$/.test(item.date) && !Number.isNaN(Date.parse(item.date)) &&
      typeof item.done === 'boolean');
  } catch {
    return [];
  }
}

let tasks = loadTasks();

function saveTasks() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(tasks));
    warning.hidden = true;
  } catch {
    warning.hidden = false;
  }
  render();
}

function localToday() {
  const today = new Date();
  return [today.getFullYear(), today.getMonth() + 1, today.getDate()]
    .map(part => String(part).padStart(2, '0')).join('-');
}

function taskRow(task, today) {
  const row = document.createElement('li');
  row.className = 'task';
  const label = document.createElement('label');
  label.className = 'task-label';
  const checked = document.createElement('input');
  checked.type = 'checkbox';
  checked.checked = task.done;
  checked.addEventListener('change', () => {
    task.done = checked.checked;
    saveTasks();
  });

  const title = document.createElement('span');
  title.textContent = task.title;
  label.append(checked, title);
  if (task.done) row.classList.add('done');

  const date = document.createElement('time');
  date.dateTime = task.date;
  date.textContent = dateFormat.format(new Date(`${task.date}T00:00:00Z`));
  if (!task.done && task.date < today) {
    date.className = 'late';
    date.textContent += ' (прострочено)';
  }

  const remove = document.createElement('button');
  remove.type = 'button';
  remove.className = 'remove';
  remove.textContent = 'Видалити';
  remove.setAttribute('aria-label', `Видалити завдання ${task.title}`);
  remove.addEventListener('click', () => {
    tasks = tasks.filter(item => item.id !== task.id);
    saveTasks();
  });
  row.append(label, date, remove);
  return row;
}

function render() {
  const today = localToday();
  const sorted = [...tasks].sort((left, right) => Number(left.done) - Number(right.done) || left.date.localeCompare(right.date));
  const finished = tasks.filter(task => task.done).length;
  summary.textContent = `Виконано ${finished} з ${tasks.length}`;
  empty.hidden = tasks.length > 0;
  tasksList.replaceChildren(...sorted.map(task => taskRow(task, today)));
}

form.addEventListener('submit', event => {
  event.preventDefault();
  const titleInput = form.elements.namedItem('title');
  const deadlineInput = form.elements.namedItem('deadline');
  const title = titleInput.value.trim();
  if (!title) {
    titleInput.value = '';
    titleInput.reportValidity();
    return;
  }

  const bytes = crypto.getRandomValues(new Uint8Array(12));
  const id = Array.from(bytes, value => value.toString(16).padStart(2, '0')).join('');
  tasks.push({ id, title, date: deadlineInput.value, done: false });
  form.reset();
  titleInput.focus();
  saveTasks();
});

render();
