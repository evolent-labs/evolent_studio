<script lang="ts">
  let {
    label,
    value,
    min,
    max,
    step = 1,
    text,
    onchange,
  }: {
    label: string;
    value: number;
    min: number;
    max: number;
    step?: number;
    text?: string;
    onchange: (value: number) => void;
  } = $props();
</script>

<label>
  <span class="h"><span>{label}</span><span>{text ?? value}</span></span>
  <input type="range" {min} {max} {step} {value} style:--pct="{((value - min) / (max - min || 1)) * 100}%" oninput={(e) => onchange(+(e.currentTarget as HTMLInputElement).value)} />
</label>
