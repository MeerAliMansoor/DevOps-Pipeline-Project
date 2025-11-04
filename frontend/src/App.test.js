import { render, screen } from '@testing-library/react';
import App from './App';

test('renders frontend + backend connection header', () => {
  render(<App />);
  const headerElement = screen.getByText(/frontend \+ backend connection/i);
  expect(headerElement).toBeInTheDocument();
});

test('renders connecting paragraph', () => {
  render(<App />);
  const paragraphElement = screen.getByText(/connecting/i);
  expect(paragraphElement).toBeInTheDocument();
});

